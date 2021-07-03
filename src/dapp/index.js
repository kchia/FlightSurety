import DOM from "./dom";
import Contract from "./contract";
import "./flightsurety.css";

(async () => {
  const contract = new Contract("localhost", () => {
    // Populate the airlines into the appropriate dropdown menus
    const airlineDropdownSelect = DOM.elid("airline-select");
    const registerFlightAirlineDropdownSelect = DOM.elid(
      "register-flight-airline-select"
    );

    contract.airlines.forEach((airline, index) => {
      const option = document.createElement("option");
      option.setAttribute("value", airline);
      option.innerText = `Airline ${index + 1}`;
      airlineDropdownSelect.append(option);
      registerFlightAirlineDropdownSelect.append(option.cloneNode(true));
    });

    // Get contract operational status
    contract.isOperational((error, result) => {
      display("Operational Status", "Check if contract is operational", [
        { label: "Operational Status", error: error, value: result },
      ]);
    });

    // Fund airline
    DOM.elid("send-funds").addEventListener("click", (event) => {
      event.preventDefault();
      contract.fundAirline(
        DOM.elid("airline-select").value,
        DOM.elid("airline-ether-amount").value,
        (error, result) => {
          console.log(error, result);
        }
      );
    });

    // Register flight
    DOM.elid("register-flight").addEventListener("click", (event) => {
      event.preventDefault();
      contract.registerFlight(
        DOM.elid("register-flight-airline-select").value,
        DOM.elid("register-flight-name").value,
        DOM.elid("register-flight-timestamp").value,
        (error, result) => {
          console.log(error, result);
        }
      );
    });

    // Buy flight insurance
    DOM.elid("buy-flight-insurance").addEventListener("click", (event) => {
      event.preventDefault();
      contract.buyInsurance(
        contract.airlines[0],
        DOM.elid("flight-select").value,
        "1457002775",
        DOM.elid("flight-ether-amount").value,
        (error, result) => {
          console.log(error, result);
        }
      );
    });

    // Get flight update
    DOM.elid("submit-to-oracles").addEventListener("click", (event) => {
      event.preventDefault();
      contract.fetchFlightStatus(
        DOM.elid("flight-number").value,
        (error, result) => {
          display("Oracles", "Trigger oracles", [
            {
              label: "Fetch Flight Status",
              error: error,
              value: result.flight + " " + result.timestamp,
            },
          ]);
        }
      );
    });

    // Claim insurance
    DOM.elid("claim-insurance").addEventListener("click", (event) => {
      event.preventDefault();
      contract.claimInsurance((error, result) => {
        console.log(error, result);
      });
    });
  });
})();

function display(title, description, results) {
  let displayDiv = DOM.elid("display-wrapper");
  let section = DOM.section();
  section.appendChild(DOM.h2(title));
  section.appendChild(DOM.h5(description));
  results.map((result) => {
    let row = section.appendChild(DOM.div({ className: "row" }));
    row.appendChild(DOM.div({ className: "col-sm-4 field" }, result.label));
    row.appendChild(
      DOM.div(
        { className: "col-sm-8 field-value" },
        result.error ? String(result.error) : String(result.value)
      )
    );
    section.appendChild(row);
  });
  displayDiv.append(section);
}
