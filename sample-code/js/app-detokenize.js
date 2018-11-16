/*
* Load and control the embedded detokenize iFrame
*
* Copyright © 2017-2018 Auric Systems International. All rights reserved.
* Licensed under The 3-Clause BSD License.
*/

"use strict";

$(document).ready(function () {
    /* Bind to the submit button on the credentials form. */
    $("#credentials-form").submit(function (event) {
        /* need to call prevent-default because the Ajax call is asynchronous */
        event.preventDefault();

        // Gather the credentials.
        var configuration = $("#credentials-form input[name=configuration]").val();
        var mtid = $("#credentials-form input[name=mtid]").val();
        var segment = $("#credentials-form input[name=segment]").val();
        var secret = $("#credentials-form input[name=secret]").val();

        /* Get us a session. */
        ajaxGetSession(configuration, mtid, segment, "forever", secret, iFrameLoader);

        /* ajaxTokenize is async. We will come back here and exit.
         * That's why we needed to do event.preventDefault() above.
         */
    });
});


/*
 * Load the iFrame.
 * Pass in the sessionID and the trace ID.
 * The trace ID is used for troubleshooting.
 */
function iFrameLoader(auvSessionId, vaultTraceUID) {
    var auvToken = $("#credentials-form input[name=auvToken]").val();

    $("#embedded").attr(
        "src",
        "../embedded-detokenize.html?sessionID=" + auvSessionId +
        "&vault_trace_uid=" + vaultTraceUID +
        "&auvToken=" + auvToken);
    $("#credentials-section").addClass("hidden");
    $("#output-section").removeClass("hidden");
}



/*
 * Associate messages with functions.
 */
function bindEvent(element, eventName, eventHandler) {
    if (element.addEventListener) {
        element.addEventListener(eventName, eventHandler, false);
    } else if (element.attachEvent) {
        element.attachEvent("on" + eventName, eventHandler);
    }
}


/*
 * Associate each message from the embedded iFrame with
 * a local function.
 */
bindEvent(window, "message", function (e) {
    // console.log(e.data);
    var tag = e.data.tag || "";
    var data = e.data.data;

    if (tag == "auv_decrypted") {
        auv_decrypted();
    } else if (tag == "auv_error") {
        auv_error(data.code, data.message);
    } else if (tag == "auv_timeout") {
        auv_timeout();
    } else if (tag == "validation_errors") {
        show_validation_errors(data);
    }
})

function show_validation_errors(data) {

    console.log(data);

    $("#embedded").attr("src", "");
    var msg = "Validation errors: \n";
    var len = data.length;
    for (var i = 0; i < len; i++) {
        msg += data[i] + "\n";
    }
    show_auv_message(msg);
    $("#output").addClass("hidden");
    $("#credentials-section").removeClass("hidden");
}

/*
 * Show errors and messages.
 * In production, you hook in your own data flow and messaging.
 */
function show_auv_message(msg) {
    // console.log(msg);
    alert(msg);
}

/* ******
 * Messages sent by the embedded iFrame
 * ***** */


/*
 * Embedded iFrame displayed successfully decrypted credit card number.
 */
function auv_decrypted() {
    show_auv_message("Decrypted the AuricVault® token.");
}


/*
 * The AuricVault sessionID's lifetime was exceeded.
 * Need to get new sessionID.
 */
function auv_timeout() {
    $("#embedded").attr("src", "");
    show_auv_message("Session expired.");
    $("#credentials-section").removeClass("hidden");
    $("#output-section").addClass("hidden");
}


/*
 * An error occurred.
 * In production, you may want to log this.
 * Auric recommends you include the vaultTraceUID in your logs.
 * This will help with problem solving.
 */
function auv_error(error_code, error_message) {
    var msg = "The AuricVault® service request failed. Code: " + error_code + ", error: " + error_message;
    show_auv_message(msg);
    $("#credentials-section").removeClass("hidden");
    $("#output-section").addClass("hidden");
}
