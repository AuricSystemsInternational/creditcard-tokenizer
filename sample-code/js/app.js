/*
* Utility functions for the sample AuricVault® service browser-side tokenization demo.
* Copyright © 2017-2018 Auric Systems International. All rights reserved.
* Licensed under The 3-Clause BSD License.
*/


"use strict";

var vault_url = 'https://vault02-sb.auricsystems.com/vault/v2/';

// track the creditcardvalidation request id
var ccRequestId = "";


function toHex(str) {
    var hex = '';
    for(var i=0;i<str.length;i++) {
        hex += ''+str.charCodeAt(i).toString(16);
    }
    return hex;
}

 /* String Substitution */
String.prototype.format = function() {
    var formatted = this;
    for( var arg in arguments ) {
        formatted = formatted.replace("{" + arg + "}", arguments[arg]);
    }
    return formatted;
};


/* UTC Timestamp (in seconds) */
function utcTimestamp() {
    var x = new Date();
    return Math.floor((x.getTime()) / 1000).toString();
};


/*  Random Ajax transaction identifier. Between 0 and 1,000,000.
    NOTE: ajax_id MUST be an integer, not a string.
 */
function generateAjaxId() {
    return Math.floor((Math.random() * 1000000) + 1);
};

$(document).ready(function() {
    /* Bind to the button. */
    $("#credentials-form").submit(function(event) {
        /* need to call prevent-default because the Ajax call is asynchronous */
        event.preventDefault();

        // Gather the data.
        var configuration = $("#credentials-form input[name=configuration]").val();
        var mtid = $("#credentials-form input[name=mtid]").val();
        var segment = $("#credentials-form input[name=segment]").val();
        var secret = $("#credentials-form input[name=secret]").val();
        var retention = $("#credentials-form input[name=retention]").val();

        /* Get us a session. */
        ajaxGetSession(configuration, mtid, segment, retention, secret);

        /* ajaxTokenize is async. We will come back here and exit.
           That's why we needed to do event.preventDefault() above.
         */
    });

    $("#tokenize").click(function(event){
         event.preventDefault();

         ccRequestId =  validateCreditCard();
    });
});


function validateCreditCard(){

    //A sample request ID
    var requestId = "isCreditCardValid:" + Math.random();
    var msg = {
        tag: "isCreditCardValid",
        data: requestId
    };
//             console.log(msg);
    sendMessage(msg);
    return requestId;
}
function ajaxGetSession(configuration, mtid, segment, retention, secret) {
    var params = {
        "id": generateAjaxId(),
        "method": "get_session",
        "params": [{
            "utcTimestamp": utcTimestamp(),
            "configurationId": configuration,
            "mtid": mtid,
            "retention": retention,
            "segment": segment
            }]
        };
    var vault_trace_uid = uuid4();
    var json_data = JSON.stringify(params)
    var hex_secret = toHex(secret)
    var hash = new jsSHA("SHA-512", "TEXT")
    hash.setHMACKey(hex_secret, "HEX")
    hash.update(json_data)
    var hmac = hash.getHMAC("HEX")

    $.ajax({
        type: 'POST',
        url: vault_url,
        beforeSend: function(xhr) {
            xhr.setRequestHeader("X-VAULT-HMAC", hmac);
            xhr.setRequestHeader("X-VAULT-TRACE-UID", vault_trace_uid);
            },
        crossDomain: true,
        dataType: 'json',
        timeout: 1000 * 5,
        data: json_data,
        success: function(data, textStatus, jqXHR) {
            var json = JSON.stringify(data);
            var las = data['result']['lastActionSucceeded'];
            if(0 == las) {
               console.log('Problem..');
               // alert("We've experienced a processing error. Please try again.");
                /* This would be a good place to log an error
                   using whatever error tracking system you have.

                   Never show the following alert in production.
                 */
                alert(data['error']);
            } else {
                /* Load the embedded iFrame */
                console.log('SUCCESS!!');

                var sessionId = data['result']['sessionId'];
                var cardtypes = $("#cardTypes").val();

               $('#embedded').attr(
                    'src',
                    '../embedded-tokenize.html?sessionID=' + sessionId +
                    '&vault_trace_uid=' + vault_trace_uid +
                    '&cardTypes=' + cardtypes);
               $("#credentials-section").addClass("hidden");
               $("#output").removeClass("hidden");
            };
        },
        error: function(jqXHR, textStatus, errorThrown) {
            console.log('ISSUES!!');
            // Another good place to log an error.
            // alert("We've experienced a processing error. Please try again.");
            // Never show alert in production.
            alert(errorThrown);
        },
    });
}

function tokenize(){
    // Validation returned successfully.
    // Send tokenization request to iFrame.
    var msg = {
        tag: "tokenize"
    };

    sendMessage(msg);

}
//send message to iframe
var sendMessage = function(msg) {
   var embeddedTokenizer = document.getElementById("embedded");
   embeddedTokenizer.contentWindow.postMessage(msg, "*");
}

function bindEvent(element, eventName, eventHandler) {
   if (element.addEventListener){
       element.addEventListener(eventName, eventHandler, false);
   } else if (element.attachEvent) {
       element.attachEvent('on' + eventName, eventHandler);
   }
}

bindEvent(window, "message", function(e){
   //console.log(e);
   var tag = e.data.tag || "";
   var data = e.data.data;

   if (tag == "auv_ok"){
       auv_ok(data.token, data.cardType)
   } else if (tag == "auv_error"){
       auv_error(data.code, data.message);
   } else if (tag == "auv_timeout"){
       auv_timeout();
   } else if (tag == "cc_valid"){
       creditcard_valid(data.requestId, data.isValid);
   }

})

function show_auv_message(msg){
   alert(msg);
}

//API functions
function auv_ok(token, card_type){
   $('#embedded').attr('src', '');
   var msg = "Tokenization succeeded.\nToken: " + token + "\nCard type: " + card_type;
   show_auv_message(msg);
   $("#output").addClass("hidden");
   $("#credentials-section").removeClass("hidden");
}

function auv_timeout(){
   $('#embedded').attr('src', '');
   show_auv_message("AUV request timed out.");
   $("#output").addClass("hidden");
   $("#credentials-section").removeClass("hidden");
}

function auv_error(error_code, error_message){
   $('#embedded').attr('src', '');
   var msg = "AUV request failed. Code: " + error_code + ", error: " + error_message;
   show_auv_message(msg);
   $("#output").addClass("hidden");
   $("#credentials-section").removeClass("hidden");
}
function creditcard_valid(requestId, isValid){
   //message from embedded iframe indicating whether
   //a credit card is valid or not. This message is generated in response
   //to a isCreditCardValid request identified by the request id
   //Further action can be taken here based on that response

   //now tokenize of valid and requestId matches
   if (isValid && requestId === ccRequestId) {
       console.log("Credit card data is valid. Tokenizing...")
       tokenize();
   }
   else {
       var msg = "Credit card data is not valid.";
       show_auv_message(msg);
   }
}
