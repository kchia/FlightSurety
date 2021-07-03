// SPDX-License-Identifier: MIT
pragma solidity 0.5.7;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    struct Airline {
        bool isRegistered;
        uint256 funds;
    }

    struct Flight {
        address airline;
        string name;
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
    }

    struct Insurance {
        uint256 amount;
        uint256 payout;
    }

    address private contractOwner;
    bool public operational = true;
    uint256 private enabled = block.timestamp;
    uint256 private counter = 1;

    uint256 private registeredAirlinesCount = 0;

    mapping(address => uint256) authorizedContracts;
    mapping(address => Airline) airlines;
    mapping(address => address[]) votes;
    mapping(bytes32 => Flight) private flights;
    mapping(bytes32 => Insurance) private insurances;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    /**
     * @dev Constructor
     *      The deploying account becomes contractOwner
     */
    constructor(address airline) public {
        contractOwner = msg.sender;
        airlines[airline] = Airline({isRegistered: true, funds: 0});
        registeredAirlinesCount++;
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
     * @dev Modifier that requires the "operational" boolean variable to be "true"
     *      This is used on all state changing functions to pause the contract in
     *      the event there is an issue that needs to be fixed
     */
    modifier requireIsOperational() {
        require(operational, "Contract is currently not operational");
        _; // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
     * @dev Modifier that requires the "ContractOwner" account to be the function caller
     */
    modifier requireContractOwner(address caller) {
        require(caller == contractOwner, "Caller is not contract owner");
        _;
    }

    /**
     * @dev Modifier that requires the caller to be an authorized contract
     */
    modifier requireIsAuthorized() {
        require(
            authorizedContracts[msg.sender] == 1,
            "Caller is not authorized"
        );
        _;
    }

    /**
     * @dev Modifier that serves as a re-entrancy guard
     */
    modifier requireReentrancyGuard(uint256 time) {
        counter = counter.add(1);
        uint256 guard = counter;
        _;
        require(guard == counter, "That is not allowed");
    }

    modifier requireHasEligibleCredit(bytes32 key) {
        require(insurances[key].payout > 0, "Passenger has no eligible credit");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
     * @dev Get operating status of contract
     *
     * @return A bool that is the current operating status
     */
    function isOperational() public view returns (bool) {
        return operational;
    }

    /**
     * @dev Sets contract operations on/off
     *
     * When operational mode is disabled, all write transactions except for this one will fail
     */
    function setOperatingStatus(bool mode, address caller)
        external
        requireContractOwner(caller)
    {
        operational = mode;
    }

    /**
     * @dev Check if an airline is registered
     *
     * @return A bool that indicates if the airline is registered
     */
    function isAirlineRegistered(address account) external view returns (bool) {
        require(account != address(0), "'account' must be a valid address.");
        return airlines[account].isRegistered;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    function authorizeContract(address contractAddress, address caller)
        external
        requireContractOwner(caller)
    {
        authorizedContracts[contractAddress] = 1;
    }

    function deauthorizeContract(address contractAddress, address caller)
        external
        requireContractOwner(caller)
    {
        delete authorizedContracts[contractAddress];
    }

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     *
     */

    function fundAirline(address airline, uint256 amount) public payable {
        airlines[airline].funds = airlines[airline].funds.add(amount);
    }

    function getAirline(address airline) external view returns (bool, uint256) {
        return (airlines[airline].isRegistered, airlines[airline].funds);
    }

    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     *
     */
    function registerAirline(
        address account,
        bool isRegistered,
        address voter
    ) external payable requireIsAuthorized {
        votes[account].push(voter);
        airlines[account] = Airline({isRegistered: isRegistered, funds: 0});
    }

    function getAirlineVotes(address airline)
        external
        view
        returns (address[] memory)
    {
        return votes[airline];
    }

    function getRegisteredAirlinesCount()
        external
        view
        returns (uint256 count)
    {
        count = registeredAirlinesCount;
    }

    function updateRegisteredAirlinesCount() external {
        registeredAirlinesCount = registeredAirlinesCount.add(1);
    }

    /**
     * @dev Register a future flight for insuring.
     *
     */
    function registerFlight(
        address airline,
        string calldata name,
        uint256 timestamp,
        uint8 statusCode
    ) external requireIsAuthorized {
        bytes32 key = keccak256(
            abi.encodePacked(airline, name, timestamp, statusCode)
        );
        require(!flights[key].isRegistered, "Flight is already registered.");

        flights[key] = Flight({
            isRegistered: true,
            name: name,
            statusCode: statusCode,
            updatedTimestamp: timestamp,
            airline: airline
        });
    }

    /**
     * @dev Buy insurance for a flight
     *
     */
    function updateInsurances(bytes32 key, uint256 amount) external {
        insurances[key].amount = amount;
    }

    /**
     * @dev Get flight insurance by key
     *
     */
    function getInsurance(bytes32 key) external view returns (uint256) {
        return insurances[key].amount;
    }

    /**
     *  @dev Credits payouts to insurees
     */
    function creditInsurees(bytes32 key, uint256 credit) external {
        insurances[key].payout = credit;
    }

    /**
     *  @dev Transfers ALL eligible payout funds to insuree
     *
     */
    function withdraw(address payable passenger, bytes32 key)
        external
        payable
        requireHasEligibleCredit(key)
    {
        uint256 amount = insurances[key].payout;
        insurances[key].payout = 0;
        passenger.transfer(amount);
    }

    /**
     * @dev Fallback function for funding smart contract.
     *
     */
    function() external payable {
        require(
            msg.data.length == 0,
            "Message data not allowed in a fallback function"
        );
    }
}
