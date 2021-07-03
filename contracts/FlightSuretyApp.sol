// SPDX-License-Identifier: MIT
pragma solidity 0.5.7;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./FlightSuretyData.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codes
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    uint256 constant AIRLINE_REGISTRATION_FEE = 10 ether;
    uint256 constant MINIMUM_REGISTERED_AIRLINES_COUNT = 4;
    uint256 constant CONSENSUS = 5; // % of votes needed for consensus

    address private contractOwner; // Account used to deploy contract
    FlightSuretyData flightSuretyData;

    // Data variables for rate-limiting modifier
    uint256 private enabled = block.timestamp;
    uint256 private counter = 1;

    event AirlineFunded(address funder, uint256 amount);
    event AirlineRegistered(
        address registeredBy,
        address registeredAccount,
        uint256 registeredAirlinesCount
    );
    event FlightRegistered(address airline, string name, uint256 timestamp);
    event FlightInsuranceBought(string flight, address passenger);
    event FlightInsuranceCredited(address passenger, uint256 credit);

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
        // Modify to call data contract's status
        require(
            flightSuretyData.isOperational(),
            "Contract is currently not operational"
        );
        _; // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
     * @dev Modifier that requires the "ContractOwner" account to be the function caller
     */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /**
     * @dev Modifier that requires the caller to not be a contract account
     */
    modifier requireNonContractAccount(address account) {
        require(msg.sender == tx.origin, "Contracts not allowed");
        _;
    }

    /**
     * @dev Modifier that requires the caller to adhere to a specific rate limit
     */
    modifier requireRateLimit(uint256 time) {
        require(block.timestamp >= enabled, "Rate-limiting in effect");
        enabled = enabled.add(time);
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

    /**
     * @dev Modifier that requires the caller is a registered airline
     */
    modifier requireIsRegisteredAirline() {
        bool isRegistered;
        (isRegistered, ) = flightSuretyData.getAirline(msg.sender);
        require(isRegistered == true, "Caller is not a registered airline");
        _;
    }

    /**
     * @dev Modifier that requires the caller has met minimum funding amount
     */
    modifier requireCallerHasEnoughFunding() {
        (, uint256 funds) = flightSuretyData.getAirline(msg.sender);
        require(
            funds >= AIRLINE_REGISTRATION_FEE,
            "Caller has not met minimal funding amount"
        );
        _;
    }

    /**
     * @dev Modifier that requires the airline is not yet registered
     */
    modifier requireAirlineIsNotRegistered(address account) {
        bool isRegistered;
        (isRegistered, ) = flightSuretyData.getAirline(account);
        require(!isRegistered, "Airline is already registered.");
        _;
    }

    /**
     * @dev Modifier that requires the caller has not voted
     */
    modifier requireCallerHasNotVoted(address account) {
        bool hasVoted = false;
        address[] memory votes = flightSuretyData.getAirlineVotes(account);
        for (uint256 index = 0; index < votes.length; index++) {
            if (votes[index] == msg.sender) {
                hasVoted = true;
                break;
            }
        }
        require(!hasVoted, "Caller has already voted for the airline");
        _;
    }

    /**
     * @dev Modifier that requires the flight is delayed due to airline's fault
     */
    modifier requireFlightIsDelayedByAirline(uint8 statusCode) {
        require(
            statusCode == STATUS_CODE_LATE_AIRLINE,
            "Flight is delayed due to airline's fault"
        );
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
     * @dev Contract constructor
     *
     */
    constructor(address payable dataContract) public {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(dataContract);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() public view returns (bool) {
        return flightSuretyData.isOperational();
    }

    function normalize(uint256 number) public pure returns (uint256) {
        return number.mul(10);
    }

    function calculateCredit(uint256 amount) public pure returns (uint256) {
        return amount.mul(3).div(2);
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
     * @dev Fund an airline
     *
     */
    function fundAirline()
        external
        payable
        requireIsOperational
        requireIsRegisteredAirline
    {
        flightSuretyData.fundAirline(msg.sender, msg.value);
        emit AirlineFunded(msg.sender, msg.value);
    }

    /**
     * @dev Add an airline to the registration queue
     *
     */
    function registerAirline(address account)
        external
        payable
        requireIsOperational
        requireNonContractAccount(account)
        requireAirlineIsNotRegistered(account)
        requireCallerHasNotVoted(account)
        requireCallerHasEnoughFunding
        returns (bool isRegistered, uint256 votesCount)
    {
        uint256 registeredAirlinesCount = flightSuretyData
        .getRegisteredAirlinesCount();

        if (registeredAirlinesCount >= MINIMUM_REGISTERED_AIRLINES_COUNT) {
            isRegistered = false;

            if (
                normalize(votesCount).div(registeredAirlinesCount) >= CONSENSUS
            ) {
                isRegistered = true;
            }
        } else {
            isRegistered = true;
        }

        if (isRegistered) {
            flightSuretyData.updateRegisteredAirlinesCount();
        }

        flightSuretyData.registerAirline(account, isRegistered, msg.sender);
        emit AirlineRegistered(msg.sender, account, registeredAirlinesCount);
    }

    /**
     * @dev Register a future flight for insuring.
     *
     */
    function registerFlight(
        address airline,
        string calldata name,
        uint256 timestamp
    ) external requireIsOperational {
        flightSuretyData.registerFlight(
            airline,
            name,
            timestamp,
            STATUS_CODE_UNKNOWN
        );

        emit FlightRegistered(airline, name, timestamp);
    }

    /**
     * @dev Buy a flight insurance
     *
     */
    function buyInsurance(
        address airline,
        string calldata flight,
        uint256 timestamp
    ) external payable requireIsOperational {
        bytes32 key = keccak256(
            abi.encodePacked(airline, flight, timestamp, msg.sender)
        );
        flightSuretyData.updateInsurances(key, msg.value);

        emit FlightInsuranceBought(flight, msg.sender);
    }

    /**
     * @dev Credit a flight insurance
     *
     */
    function creditInsurance(
        address airline,
        string memory flight,
        uint256 timestamp,
        uint8 statusCode
    )
        internal
        requireIsOperational
        requireFlightIsDelayedByAirline(statusCode)
    {
        bytes32 key = getFlightKey(airline, flight, timestamp);
        uint256 amount = flightSuretyData.getInsurance(key);
        uint256 credit = calculateCredit(amount);

        flightSuretyData.creditInsurees(key, credit);
        emit FlightInsuranceCredited(msg.sender, credit);
    }

    /**
     * @dev Credit a flight insurance
     *
     */
    function claimInsurance(
        address airline,
        string calldata flight,
        uint256 timestamp
    ) external payable {
        bytes32 key = getFlightKey(airline, flight, timestamp);
        flightSuretyData.withdraw(msg.sender, key);
    }

    /**
     * @dev Called after oracle has updated flight status
     *
     */
    function processFlightStatus(
        address airline,
        string memory flight,
        uint256 timestamp,
        uint8 statusCode
    ) internal requireIsOperational {
        creditInsurance(airline, flight, timestamp, statusCode);
    }

    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus(
        address airline,
        string calldata flight,
        uint256 timestamp
    ) external requireIsOperational {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(
            abi.encodePacked(index, airline, flight, timestamp)
        );

        ResponseInfo storage newResponse = oracleResponses[key];
        newResponse.requester = msg.sender;
        newResponse.isOpen = true;

        emit OracleRequest(index, airline, flight, timestamp);
    }

    /**
     * @dev Sets contract operations on/off
     *
     * When operational mode is disabled, all write transactions except for this one will fail
     */
    function setOperatingStatus(bool mode) public {
        bool operational = flightSuretyData.isOperational();
        require(
            mode != operational,
            "New mode must be different from existing mode"
        );
        flightSuretyData.setOperatingStatus(mode, msg.sender);
    }

    // region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;

    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester; // Account that requested status
        bool isOpen; // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses; // Mapping key is the status code reported
        // This lets us group responses and identify
        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(
        address airline,
        string flight,
        uint256 timestamp,
        uint8 status
    );

    // struct FlightStatus {
    //     bool hasStatus;
    //     uint8 status;
    // }

    // mapping(bytes32 => FlightStatus) flights;

    event OracleReport(
        address airline,
        string flight,
        uint256 timestamp,
        uint8 status
    );

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(
        uint8 index,
        address airline,
        string flight,
        uint256 timestamp
    );

    // Register an oracle with the contract
    function registerOracle()
        external
        payable
        requireIsOperational
        returns (uint8[3] memory indexes)
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({isRegistered: true, indexes: indexes});
    }

    function getMyIndexes()
        external
        view
        requireIsOperational
        returns (uint8[3] memory)
    {
        require(
            oracles[msg.sender].isRegistered,
            "Not registered as an oracle"
        );

        return oracles[msg.sender].indexes;
    }

    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse(
        uint8 index,
        address airline,
        string calldata flight,
        uint256 timestamp,
        uint8 statusCode
    ) external requireIsOperational {
        require(
            (oracles[msg.sender].indexes[0] == index) ||
                (oracles[msg.sender].indexes[1] == index) ||
                (oracles[msg.sender].indexes[2] == index),
            "Index does not match oracle request"
        );

        bytes32 key = keccak256(
            abi.encodePacked(index, airline, flight, timestamp)
        );
        require(
            oracleResponses[key].isOpen,
            "Flight or timestamp do not match oracle request"
        );

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (
            oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES
        ) {
            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }

    function getFlightKey(
        address airline,
        string memory flight,
        uint256 timestamp
    ) internal view requireIsOperational returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes(address account)
        internal
        requireIsOperational
        returns (uint8[3] memory)
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);

        indexes[1] = indexes[0];
        while (indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while ((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex(address account)
        internal
        requireIsOperational
        returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(
            uint256(
                keccak256(
                    abi.encodePacked(blockhash(block.number - nonce++), account)
                )
            ) % maxValue
        );

        if (nonce > 250) {
            nonce = 0; // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

    function getOracle(address account)
        external
        view
        requireContractOwner
        returns (uint8[3] memory)
    {
        return oracles[account].indexes;
    }
    // endregion
}
