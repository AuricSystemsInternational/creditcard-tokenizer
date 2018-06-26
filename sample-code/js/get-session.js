/*
 * NON-PRODUCTION
 * Get AuricVault® service session.
 * Never use in production -- exposes credentials.
 *
 * Copyright © 2017-2018 Auric Systems International. All rights reserved.
 * Licensed under The 3-Clause BSD License.
 */


"use strict";

var vault_url = "https://vault02-sb.auricsystems.com/vault/v2/";
var ccRequestId = ""

function toHex(str) {
    var hex = "";
    for (var i=0;i<str.length;i++) {
        hex += ""+str.charCodeAt(i).toString(16);
    }
    return hex;
}

/* String Substitution */
String.prototype.format = function() {
    var formatted = this;
    for ( var arg in arguments ) {
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

function ajaxGetSession(configuration, mtid, segment, retention, secret, iFrameLoader) {
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
        type: "POST",
        url: vault_url,
        beforeSend: function(xhr) {
            xhr.setRequestHeader("X-VAULT-HMAC", hmac);
            xhr.setRequestHeader("X-VAULT-TRACE-UID", vault_trace_uid);
            },
        crossDomain: true,
        dataType: "json",
        timeout: 1000 * 5,
        data: json_data,
        success: function(data, textStatus, jqXHR) {
            var json = JSON.stringify(data);
            var las = data["result"]["lastActionSucceeded"];
            if(0 == las) {
               console.log("Problem..");
               // alert("We've experienced a processing error. Please try again.");
                /* This would be a good place to log an error
                   using whatever error tracking system you have.

                   Never show the following alert in production.
                 */
                alert(data["error"]);
            } else {
                /* Load the embedded iFrame */
                console.log("SUCCESS!!");

                iFrameLoader(data["result"]["sessionId"], vault_trace_uid);
            };
        },
        error: function(jqXHR, textStatus, errorThrown) {
            console.log("ISSUES!!");
            // Another good place to log an error.
            // alert("We've experienced a processing error. Please try again.");
            // Never show alert in production.
            alert(errorThrown);
        },
    });
}
