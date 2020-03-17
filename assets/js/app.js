// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import css from "../css/app.css";
import "phoenix_html";

/* This handler MUST run before Phoenix socket is imported. */
window.addEventListener("beforeunload", e => { 
    e.preventDefault();
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
        this.el.addEventListener("click", _e => {
            const direction = this.el.dataset.side;
            const oppositeDirection = direction === "buy" ? "sell" : "buy";
            selectRadio("order_direction_" + oppositeDirection);
            selectOrderType("order_type_market");
            selectDropdown("order_suit", this.el.dataset.suit);
            submitOrder();
        });
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
        this.previousPoints = this.el.dataset.points;
    },

    updated() {
        const previous = this.previousPoints;
        const current = +this.el.dataset.points;
        this.previousPoints = current;
        if (current === previous) {
            return;
        }

        const animationClass = ((previous > current) ? "buy" : "sell") + "-animated";
        animateOnce(this.el, animationClass);
    }
};

Hooks.Hand = {
    mounted() {
        this.previousHand = this.el.dataset.hand;
    },

    updated() {
        const previous = this.previousHand;
        const current = +this.el.dataset.hand;
        this.previousHand = current;
        if (current === previous) {
            return;
        }

        const animationClass = ((previous > current) ? "sell" : "buy") + "-animated";
        animateOnce(this.el, animationClass);
    }
};

Hooks.OrderTypeRadio = {
    mounted() {
        this.el.addEventListener("click", function() { selectOrderType(this.id); });
    }
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

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");

const liveSocket = new LiveSocket("/live", Socket, { hooks: Hooks, params: {_csrf_token: csrfToken} });
liveSocket.connect();

function selectRadio(eid) {
    const element = document.getElementById(eid);
    if (!element) { return false; }
    element.checked = true;
    return true;
}

function selectDropdown(eid, value) {
    const dropdown = document.getElementById(eid);
    if (!dropdown) { return false; }
    dropdown.value = value;
    return true;
}

function addToPrice(digit) {
    const price = document.getElementById("order_price");
    if (!price) { return false; }
    if (!price.disabled) {
        price.value += digit;
    }
    return true;
}

function selectOrderType(eid) {
    const radio = document.getElementById(eid);
    const limitOrder = document.getElementById("order_type_limit");
    const price = document.getElementById("order_price");
    if (!radio || !limitOrder || !price) { return false; }
    radio.checked = true;
    price.disabled = !limitOrder.checked;
    return true;
}

function backspacePrice() {
    const price = document.getElementById("order_price");
    if (!price) { return false; }
    price.value = price.value.slice(0, -1);
    return true;
}

function submitOrder() {
    const submit = document.getElementById("order_submit");
    const order = document.getElementById("order")
    const price = document.getElementById("order_price");
    if (!submit || !order || !price) { return false; }
    submit.click();
    if (order.checkValidity()) {
        price.value = "";
    }
    return true;
}

function requeue() {
    const requeue = document.getElementById("requeue");
    if (!requeue) { return false; }
    requeue.click();
    return true;
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
    return el && el.id === "order_price" && e.code.startsWith("Digit");
}

function closeModalIfOpen() {
    const el = document.getElementById("modal_close");
    if (el) {
        el.click();
    }
}

document.addEventListener("keydown", e => {
    if (e.ctrlKey || e.altKey) {
        return false;
    }
    closeModalIfOpen();
    if (isTypingPrice(e)) {
        return false;
    }

    const code = e.code;
    const maybeAction = actionMap[code];

    let success;
    if (typeof maybeAction !== "undefined") {
        success = maybeAction(e);
    } else if (code.startsWith("Digit")) {
        const whichDigit = code.slice(-1);
        success = addToPrice(whichDigit);
    }

    if (success) {
        e.preventDefault();
    }
    return success;
});
