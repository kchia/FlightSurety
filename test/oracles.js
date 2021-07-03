const Test = require("../config/testConfig.js");

contract("Oracles", async (accounts) => {
  const TEST_ORACLES_COUNT = 20;
  // Watch contract events
  const STATUS_CODE_UNKNOWN = 0;
  const STATUS_CODE_ON_TIME = 10;
  const STATUS_CODE_LATE_AIRLINE = 20;
  const STATUS_CODE_LATE_WEATHER = 30;
  const STATUS_CODE_LATE_TECHNICAL = 40;
  const STATUS_CODE_LATE_OTHER = 50;

  let config;
  before("setup contract", async () => {
    config = await Test.Config(accounts);
  });

  it.only("can register oracles", async () => {
    // ARRANGE
    let fee = await config.flightSuretyApp.REGISTRATION_FEE.call();

    // ACT
    for (let index = 1; index < TEST_ORACLES_COUNT; index++) {
      await config.flightSuretyApp.registerOracle({
        from: accounts[index],
        value: fee,
      });
      let result = await config.flightSuretyApp.getMyIndexes.call({
        from: accounts[index],
      });
      console.log(
        `Oracles Registered: ${result[0]}, ${result[1]}, ${result[2]}`
      );
    }
  });

  it.only("can request flight status", async () => {
    // ARRANGE
    let flight = "ND1309"; // Course number
    let timestamp = Math.floor(Date.now() / 1000);

    // Submit a request for oracles to get status information for a flight
    await config.flightSuretyApp.fetchFlightStatus(
      config.firstAirline,
      flight,
      timestamp
    );
    // ACT

    // Since the Index assigned to each test account is opaque by design
    // loop through all the accounts and for each account, all its Indexes (indices?)
    // and submit a response. The contract will reject a submission if it was
    // not requested so while sub-optimal, it's a good test of that feature
    for (let outerIndex = 1; outerIndex < TEST_ORACLES_COUNT; outerIndex++) {
      // Get oracle information
      let oracleIndexes = await config.flightSuretyApp.getMyIndexes.call({
        from: accounts[outerIndex],
      });
      for (let index = 0; index < 3; index++) {
        try {
          // Submit a response...it will only be accepted if there is an Index match
          await config.flightSuretyApp.submitOracleResponse(
            oracleIndexes[index],
            config.firstAirline,
            flight,
            timestamp,
            STATUS_CODE_ON_TIME,
            { from: accounts[outerIndex] }
          );
        } catch (error) {
          // Enable this when debugging
          console.log(
            "\nError",
            index,
            oracleIndexes[index].toNumber(),
            flight,
            timestamp,
            error
          );
        }
      }
    }
  });
});
