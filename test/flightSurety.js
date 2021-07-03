const Test = require("../config/testConfig.js");
const BigNumber = require("bignumber.js");

contract("Flight Surety Tests", async (accounts) => {
  let config;
  before("setup contract", async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeContract(
      config.flightSuretyApp.address,
      config.owner
    );
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {
    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");
  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {
    // Ensure that access is denied for non-Contract Owner account
    let accessDenied = false;
    try {
      await config.flightSuretyData.setOperatingStatus(false, {
        from: config.testAddresses[2],
      });
    } catch (error) {
      accessDenied = true;
    }
    assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {
    // Ensure that access is allowed for Contract Owner account
    let accessDenied = false;
    try {
      await config.flightSuretyApp.setOperatingStatus(false, {
        from: config.owner,
      });
    } catch (error) {
      accessDenied = true;
    }
    assert.equal(
      accessDenied,
      false,
      "Access not restricted to Contract Owner"
    );

    // Set it back for other tests to work
    await config.flightSuretyApp.setOperatingStatus(true, {
      from: config.owner,
    });
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {
    await config.flightSuretyApp.setOperatingStatus(false, {
      from: config.owner,
    });

    let reverted = false;
    try {
      await config.flightSuretyApp.registerAirline(newAirline, {
        from: config.firstAirline,
      });
    } catch (error) {
      reverted = true;
    }
    assert.equal(reverted, true, "Access not blocked for requireIsOperational");

    // Set it back for other tests to work
    await config.flightSuretyApp.setOperatingStatus(true, {
      from: config.owner,
    });
  });

  it("(airline) cannot register an Airline using registerAirline() if it is not funded", async () => {
    // ARRANGE
    let newAirline = accounts[2];
    let result = true;

    // ACT
    try {
      await config.flightSuretyApp.registerAirline(newAirline, {
        from: config.firstAirline,
      });
    } catch (error) {
      result = await config.flightSuretyData.isAirlineRegistered.call(
        newAirline
      );
    }

    // ASSERT
    assert.equal(
      result,
      false,
      "Airline should not be able to register another airline if it hasn't provided funding"
    );
  });

  it("(airline) can register another airline only if it submits a funding of at least 10 ether", async () => {
    let newAirline = accounts[2];
    try {
      await config.flightSuretyApp.fundAirline({
        from: config.firstAirline,
        value: web3.utils.toWei("10", "ether"),
        gasPrice: 3000000,
      });
      await config.flightSuretyApp.registerAirline(newAirline, {
        from: config.firstAirline,
      });
    } catch (error) {}

    let result = await config.flightSuretyData.isAirlineRegistered.call(
      newAirline
    );

    assert.equal(
      result,
      true,
      "Airline should be able to register another airline if it has provided enough funding"
    );
  });

  it("(airline) may not register another airline more than once", async () => {
    let newAirline = accounts[2];
    let revert = false;
    try {
      await config.flightSuretyApp.registerAirline(newAirline, {
        from: config.firstAirline,
      });
    } catch (error) {
      revert = true;
    }

    assert.equal(
      revert,
      true,
      "Airline should not register another airline more than once"
    );
  });

  it("(airline) may NOT register a new airline if there are more than four airlines currently registered", async () => {
    let newAirline3 = accounts[3];
    let newAirline4 = accounts[4];
    let newAirline5 = accounts[5];

    try {
      await config.flightSuretyApp.registerAirline(newAirline3, {
        from: config.firstAirline,
      });
      await config.flightSuretyApp.registerAirline(newAirline4, {
        from: config.firstAirline,
      });
      await config.flightSuretyApp.registerAirline(newAirline5, {
        from: config.firstAirline,
      });
    } catch (error) {}

    let result = await config.flightSuretyData.isAirlineRegistered.call(
      newAirline5
    );

    assert.equal(
      result,
      false,
      "Airline may not single-handedly register another airline if there are at least four currently registered airlines"
    );
  });

  it("registration of fifth and subsequent airlines requires multi-party consensus of 50% of registered airlines", async () => {
    let secondAirline = accounts[2];
    let thirdAirline = accounts[3];
    let fourthAirline = accounts[4];
    let newAirline = accounts[5];

    try {
      await config.flightSuretyApp.fundAirline({
        from: config.secondAirline,
        value: web3.utils.toWei("10", "ether"),
        gasPrice: 3000000,
      });

      await config.flightSuretyApp.registerAirline(newAirline, {
        from: secondAirline,
      });

      await config.flightSuretyApp.fundAirline({
        from: config.thirdAirline,
        value: web3.utils.toWei("10", "ether"),
        gasPrice: 3000000,
      });

      await config.flightSuretyApp.registerAirline(newAirline, {
        from: thirdAirline,
      });
    } catch (error) {}

    let result = await config.flightSuretyData.isAirlineRegistered.call(
      newAirline
    );

    assert.equal(
      result,
      true,
      "Airline may not be registered without at least 50% consensus amongst registered airlines"
    );
  });
});
