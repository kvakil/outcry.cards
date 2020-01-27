// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import css from "../css/app.css";

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import dependencies
//
import "phoenix_html";

// Import local files
//
// Local files can be imported directly using relative paths, for example:
// import socket from "./socket"
import {Socket} from "phoenix";

const Hooks = {};

// Animates an element once, even if morphdom tries to recreate it.
function animateOnce(element, animationClass) {
    element.classList.add(animationClass);
    element.addEventListener("animationend", _e => element.classList.remove(animationClass));
}

Hooks.Order = {
    mounted() {
        animateOnce(this.el, "animated");
    }
};

Hooks.History = {
    mounted() {
        const history = document.getElementById("trade_history");
        history.scrollTop = history.scrollHeight;
    }
};

Hooks.Points = {
    previousPoints: {},

    updated() {
        const previous = this.previousPoints[this.el.id];
        const current = +this.el.innerText;
        this.previousPoints[this.el.id] = current;
        if (previous === undefined || current == previous) {
            return;
        }

        const animationClass = ((previous > current) ? "buy" : "sell") + "-animated";
        animateOnce(this.el, animationClass);
    }
};

Hooks.Hand = {
    previousHand: {},

    updated() {
        const previous = this.previousHand[this.el.id];
        const current = +this.el.innerText.slice(1, -1);
        this.previousHand[this.el.id] = current;
        if (previous === undefined || current == previous) {
            return;
        }

        const animationClass = ((previous > current) ? "sell" : "buy") + "-animated";
        animateOnce(this.el, animationClass);
    }
};

Hooks.EndGame = {
    mounted() {
        Hooks.Points.previousPoints = {};
        Hooks.Hand.previousHand = {};
    }
};

let socket = new Socket("/socket", {});

// LiveView
import LiveSocket from "phoenix_live_view";

let liveSocket = new LiveSocket("/live", Socket, { hooks: Hooks });
liveSocket.connect();

function selectRadio(eid) {
    const element = document.getElementById(eid);
    element.checked = true;
}

function selectDropdown(eid, value) {
    const dropdown = document.getElementById(eid);
    dropdown.value = value;
}

function addToPrice(digit) {
    const price = document.getElementById("order_price");
    if (!price.disabled) {
        price.value += digit;
    }
}

function selectOrderType(eid) {
    const radio = document.getElementById(eid);
    radio.checked = true;
    const limitOrder = document.getElementById("order_type_limit");
    const price = document.getElementById("order_price");
    price.disabled = !limitOrder.checked;
}

function backspacePrice() {
    const price = document.getElementById("order_price");
    price.value = price.value.slice(0, -1);
}

function submitOrder() {
    document.getElementById("order_submit").click();
    if (document.getElementById("order").checkValidity()) {
        document.getElementById("order_price").value = "";
    }
}

function requeue() {
    document.getElementById("requeue").click();
}

const actionMap = {
    "KeyA": _e => selectRadio("order_direction_buy"),
    "KeyS": _e => selectRadio("order_direction_sell"),
    "KeyH": _e => selectDropdown("order_suit", "h"),
    "KeyJ": _e => selectDropdown("order_suit", "j"),
    "KeyK": _e => selectDropdown("order_suit", "k"),
    "KeyL": _e => selectDropdown("order_suit", "l"),
    "KeyZ": _e => selectOrderType("order_type_limit"),
    "KeyX": _e => selectOrderType("order_type_market"),
    "KeyC": _e => selectOrderType("order_type_cancel"),
    "KeyY": _e => requeue(),
    "Backspace": _e => backspacePrice(),
    "Enter": _e => submitOrder()
}

function isTypingPrice() {
    const el = document.activeElement;
    return el && el.id == "order_price";
}

document.addEventListener("keydown", e => {
    if (isTypingPrice()) {
        return false;
    }
    if (e.ctrlKey || e.altKey) {
        return false;
    }
    const code = e.code;
    const maybeAction = actionMap[code];
    if (typeof maybeAction !== "undefined") {
        e.preventDefault();
        return maybeAction(e);
    } else if (code.startsWith("Digit")) {
        e.preventDefault();
        const whichDigit = code.slice(-1);
        return addToPrice(whichDigit);
    }
});
