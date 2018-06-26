/*
 * Load and control the embedded tokenize iFrame
 *
 * Copyright © 2017-2018 Auric Systems International. All rights reserved.
 * Licensed under The 3-Clause BSD License.
 */

"use strict";

/*
 * Bind to the submit button on the credentials form.
 * The Ajax call to get session asynchronously calls the iFrameLoader function.
 * In production, you'll typically call the iFrameLoader function when the
 * parent page loads.
 */
$(document).ready(function() {
    /* Bind to the submit button on the credentials form. */
    $("#credentials-form").submit(function(event) {
        /* Need to call prevent-default because the Ajax call is asynchronous */
        event.preventDefault();

        // Gather the credentials.
        var configuration = $("#credentials-form input[name=configuration]").val();
        var mtid = $("#credentials-form input[name=mtid]").val();
        var segment = $("#credentials-form input[name=segment]").val();
        var secret = $("#credentials-form input[name=secret]").val();
        var retention = $("#credentials-form input[name=retention]").val();

        /* Get us a session. */
        ajaxGetSession(configuration, mtid, segment, retention, secret, iFrameLoader);

        /* ajaxTokenize is async. We will come back here and exit.
         * That's why we needed to do event.preventDefault() above.
         */
    });

    /*
     * Bind to the Tokenize button.
     * Calls async function to check that card is valid.
     * The response from the embedded iFrame triggers the actual tokenization.
     * See the auv_credit_card_valid function.
     */
    $("#tokenize").click(function(event){
         event.preventDefault();

         ccRequestId =  validateCreditCard();
    });
});


/*
 * Load the iFrame.
 * Pass in the sessionID and the trace ID.
 * The trace ID is used for troubleshooting.
 */
function iFrameLoader(auvSessionId, vaultTraceUID) {
    var cardtypes = $("#cardTypes").val();

    $("#embedded").attr(
        "src",
        "../embedded-tokenize.html?sessionID=" + auvSessionId +
        "&vault_trace_uid=" + vaultTraceUID +
        "&cardTypes=" + cardtypes);
    $("#credentials-section").addClass("hidden");
    $("#output").removeClass("hidden");
}


// The embedded iFrame.
var embeddedTokenizer = document.getElementById("embedded");


/*
 * Send a message to the embedded iFrame.
 */
var sendMessage = function(msg) {
   embeddedTokenizer.contentWindow.postMessage(msg, "*");
}


/*
 * Send validation message to the iFrame to check the validity of the credit card number.
 */
function validateCreditCard(){
    var requestId = "isCreditCardValid:" + Math.random();
    var msg = {
        tag: "isCreditCardValid",
        data: requestId
    };
    // console.log(msg);
    sendMessage(msg);
    return requestId;
}


/*
 * Send tokenization message to iFrame requesting tokenization.
 * Do not send this message until after you've confirmed the credit card
 * number is valid.
 */
function tokenize(){
    var msg = {
        tag: "tokenize"
    };

    sendMessage(msg);

}


/*
 * Associate messages with functions.
 */
function bindEvent(element, eventName, eventHandler) {
   if (element.addEventListener){
       element.addEventListener(eventName, eventHandler, false);
   } else if (element.attachEvent) {
       element.attachEvent("on" + eventName, eventHandler);
   }
}


/*
 * Associate each message from the embedded iFrame with
 * a local function.
 */
bindEvent(window, "message", function(e){
   // console.log(e);
   var tag = e.data.tag || "";
   var data = e.data.data;

   if (tag == "auv_ok"){
       auv_ok(data.token, data.cardType)
   } else if (tag == "auv_error"){
       auv_error(data.code, data.message);
   } else if (tag == "auv_timeout"){
       auv_timeout();
   } else if (tag == "cc_valid"){
       auv_creditcard_valid(data.requestId, data.isValid);
   }

})


/*
 * Show errors and messages.
 * In production, you hook in your own data flow and messaging.
 */
function show_auv_message(msg){
   alert(msg);
}

/* ******
 * Messages sent by the embedded iFrame
 * ***** */


/*
 * Message from the embedded iFrame indicating whether the credit card number is valid.
 * This message is generated in response to an isCreditCardValid request and is
 * identified by the request ID.
 * If the card number is valid, the tokenization message to the embedded iFrame
 * is automatically triggered.
 */
function auv_creditcard_valid(requestId, isValid){
   if (isValid && requestId === ccRequestId) {
       // console.log("Credit card data is valid. Tokenizing...")
       tokenize();
   }
   else {
       var msg = "Credit card data is not valid.";
       show_auv_message(msg);
   }
}


/*
 * Successful tokenization.
 * Message contains the token and the method of payment.
 */
function auv_ok(token, card_type){
   $("#embedded").attr("src", "");
   var msg = "Tokenization succeeded.\nToken: " + token + "\nCard type: " + card_type;
   show_auv_message(msg);
   $("#output").addClass("hidden");
   $("#credentials-section").removeClass("hidden");
}


/*
 * The AuricVault sessionID's lifetime was exceeded.
 * Need to get new sessionID.
 */
function auv_timeout(){
   $("#embedded").attr("src", "");
   show_auv_message("Session expired.");
   $("#output").addClass("hidden");
   $("#credentials-section").removeClass("hidden");
}


/*
 * An error occurred.
 * In production, you may want to log this.
 * Auric recommends you include the vaultTraceUID in your logs.
 * This will help with problem solving.
 */
function auv_error(error_code, error_message){
   $("#embedded").attr("src", "");
   var msg = "AUV request failed. Code: " + error_code + ", error: " + error_message;
   show_auv_message(msg);
   $("#output").addClass("hidden");
   $("#credentials-section").removeClass("hidden");
}
