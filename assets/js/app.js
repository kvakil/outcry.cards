// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import css from "../css/app.css";
import "phoenix_html";

/* This handler MUST run before Phoenix socket is imported. */
window.addEventListener("beforeunload", e => { 
    e.preventDefault();
    /* Phoenix will unload the socket if it sees beforeunload. */
    e.stopImmediatePropagation();
    return e.returnValue = "Are you sure you want to leave?";
});

import {Socket} from "phoenix";

let socket = new Socket("/socket", {});

import LiveSocket from "phoenix_live_view";

/* Animates an element once, even if morphdom tries to delete & recreate it. */
function animateOnce(element, animationClass) {
    element.classList.add(animationClass);
    element.addEventListener("animationend", _e => element.classList.remove(animationClass));
}

const Hooks = {};

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
    mounted() {
        this.previousPoints = {};
    },

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
    mounted() {
        this.previousHand = {};
    },

    updated() {
        const previous = this.previousHand[this.el.id];
        const current = +this.el.innerText.slice(1, -1);
        this.previousHand[this.el.id] = current;
        if (previous === undefined || current == previous) {
            return;
        }

        const animationClass = ((previous > current) ? "sell" : "buy") + "-animated";
        animateOnce(this.el, animationClass);
    },
};

function getUnixTime() {
    return new Date().getTime();
}

Hooks.Timer = {
    interval: null,

    mounted() {
        const startTime = getUnixTime();
        const twoMinutes = 2 * 60 * 1000;
        const endTime = startTime + twoMinutes;
        this.interval = setInterval(() => {
            const now = getUnixTime();
            const timeLeft = endTime - now;
            const fractionTimeLeft = timeLeft / twoMinutes;
            if (fractionTimeLeft <= 0) {
                fractionTimeLeft = 0;
            }
            if (fractionTimeLeft <= 0.15) {
                this.el.classList.add("is-danger");
            }
            this.el.value = fractionTimeLeft;
            this.el.innerText = this.el.title = Math.round(timeLeft / 1000) + " seconds";
        }, 1000);
    },

    destroyed() {
        if (this.interval !== null) {
            clearInterval(this.interval);
            this.interval = null;
        }
    }
};

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

function isTypingPrice(e) {
    const el = document.activeElement;
    return el && el.id == "order_price" && e.code.startsWith("Digit");
}

document.addEventListener("keydown", e => {
    if (isTypingPrice(e)) {
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
