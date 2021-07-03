import FlightSuretyApp from "../../build/contracts/FlightSuretyApp.json";
import Config from "./config.json";
import Web3 from "web3";

export default class Contract {
  constructor(network, callback) {
    let config = Config[network];
    this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
    this.flightSuretyApp = new this.web3.eth.Contract(
      FlightSuretyApp.abi,
      config.appAddress
    );

    this.owner = null;
    this.airlines = [];
    this.passengers = [];
    this.initialize(callback);
  }

  initialize(callback) {
    this.web3.eth.getAccounts((error, accounts) => {
      if (accounts) {
        this.owner = accounts[0];

        let counter = 1;

        while (this.airlines.length < 5) {
          this.airlines.push(accounts[counter++]);
        }

        while (this.passengers.length < 5) {
          this.passengers.push(accounts[counter++]);
        }
      }
      callback();
    });
  }

  isOperational(callback) {
    let self = this;
    let result = self.flightSuretyApp.methods
      .isOperational()
      .call({ from: self.owner }, callback);
  }

  fetchFlightStatus(flight, callback) {
    let self = this;
    let payload = {
      airline: self.airlines[0],
      flight: flight,
      timestamp: Math.floor(Date.now() / 1000),
    };
    self.flightSuretyApp.methods
      .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
      .send({ from: self.owner }, (error, result) => {
        console.log(error, result);
        callback(error, payload);
      });
  }

  fundAirline(airline, amount) {
    this.flightSuretyApp.methods.fundAirline(airline).send(
      {
        from: this.owner,
        value: this.web3.utils.toWei(`${amount}`, "ether"),
      },
      (error, result) => {
        console.log("fundAirline: ", error, result);
      }
    );
  }

  registerFlight(airline, flight, timestamp) {
    this.flightSuretyApp.methods
      .registerFlight(airline, flight, timestamp)
      .send({ from: this.owner }, (error, result) => {
        console.log("registerFlight: ", error, result);
      });
  }

  buyInsurance(airline, flight, timestamp, amount) {
    this.flightSuretyApp.methods.buyInsurance(airline, flight, timestamp).send(
      {
        from: this.owner,
        value: this.web3.utils.toWei(`${amount}`, "ether"),
      },
      (error, result) => {
        console.log("buyFlightInsurance: ", error, result);
      }
    );
  }

  claimInsurance() {
    this.flightSuretyApp.methods.claimInsurance((error, result) => {
      console.log("claimInsurance: ", error, result);
    });
  }
}
