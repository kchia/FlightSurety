import FlightSuretyApp from "../../build/contracts/FlightSuretyApp.json";
import Config from "./config.json";
import Web3 from "web3";
import express from "express";

const config = Config["localhost"];
const web3 = new Web3(
  new Web3.providers.WebsocketProvider(config.url.replace("http", "ws"))
);

web3.eth.defaultAccount = web3.eth.accounts[0];

const flightSuretyApp = new web3.eth.Contract(
  FlightSuretyApp.abi,
  config.appAddress
);

const ORACLES_COUNT = 20;
const registeredOracles = {};
const STATUS_CODE_UNKNOWN = 0;
const STATUS_CODE_ON_TIME = 10;
const STATUS_CODE_LATE_AIRLINE = 20;
const STATUS_CODE_LATE_WEATHER = 30;
const STATUS_CODE_LATE_TECHNICAL = 40;
const STATUS_CODE_LATE_OTHER = 50;

registerOracles(ORACLES_COUNT);

flightSuretyApp.events.OracleRequest(
  {
    fromBlock: 0,
  },
  (error, event) => {
    if (error) {
      console.log(error);
    } else {
      console.log("OracleRequest");
      handleOracleResponses(event);
    }
  }
);

flightSuretyApp.events.OracleReport(
  {
    fromBlock: 0,
  },
  (error, { event, returnValues: { index, airline, flight, timestamp } }) => {
    if (error) {
      console.log(error);
    } else {
      console.log(
        `(${event}) index: ${index}, airline: ${airline}, flight: ${flight}, timestamp: ${timestamp}`
      );
    }
  }
);

flightSuretyApp.events.FlightStatusInfo(
  {
    fromBlock: 0,
  },
  (error, { event, returnValues: { airline, flight, timestamp, status } }) => {
    if (error) {
      console.log(error);
    } else {
      console.log(
        `(${event}) airline: ${airline}, flight: ${flight}, timestamp: ${timestamp}, status: ${status}`
      );
    }
  }
);

async function registerOracles(count) {
  try {
    const accounts = await web3.eth.getAccounts();
    accounts.forEach((account, index) => {
      if (index < count) {
        flightSuretyApp.methods.registerOracle.send(
          {
            from: account,
            value: web3.utils.toWei("1", "ether"),
            gas: 3000000,
          },
          (error, result) => {
            flightSuretyApp.methods.getMyIndexes
              .call({
                from: account,
                gas: 500000,
              })
              .then((result) => {
                registeredOracles[account] = result;
                console.log(registeredOracles);
              });
          }
        );
      }
    });
  } catch (error) {
    console.log(error);
  }
}

function handleOracleResponses({
  returnValues: { index: desiredIndex, airline, flight, timestamp },
}) {
  const matchingOracles = [];
  for (let [address, indexes] of registeredOracles) {
    indexes.forEach((index) => {
      if (index === desiredIndex) {
        matchingOracles.push(address);
        console.log(`${desiredIndex} -> ${address}`);
      }
    });
  }

  matchingOracles.forEach((oracleAddress) => {
    flightSuretyApp.methods
      .submitOracleResponse(
        index,
        airline,
        flight,
        timestamp,
        (Math.floor(Math.random() * 6) + 1) * 10
      )
      .send({ from: oracleAddress, gas: "999999" }, (error, result) => {
        if (error) {
          console.log(
            `${oracleAddress} was rejected with status ${statusCode}`
          );
        }
      });
  });
}

const app = express();
app.get("/api", (req, res) => {
  res.send({
    message: "An API for use with your Dapp!",
  });
});

export default app;
