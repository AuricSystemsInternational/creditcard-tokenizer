        /* Utility Functions
           In production, all this JavaScript would be served by externally
           loaded scripts. Shown here inline to simplify the sample code.
         */
        "use strict";

        var vault_url = 'https://vault02-sb.auricsystems.com/vault/v2/';

        function toHex(str) {
            var hex = '';
            for(var i=0;i<str.length;i++) {
                hex += ''+str.charCodeAt(i).toString(16);
            }
            return hex;
        }

        /*
         * JavaScript UUID Generator, v0.0.1
         *
         * Copyright (c) 2009 Massimo Lombardo.
         * Dual licensed under the MIT and the GNU GPL licenses.
         * https://forum.jquery.com/topic/jquery-what-do-you-recommend-to-generate-uuid-with-jquery
          * NOTE from ASI: Math.random is sufficiently random for this tracking purpose.
         */
        function uuid4() {
            var uuid = (function () {
                var i,
                    c = "89ab",
                    u = [];
                for (i = 0; i < 36; i += 1) {
                    u[i] = (Math.random() * 16 | 0).toString(16);
                }
                u[8] = u[13] = u[18] = u[23] = "-";
                u[14] = "4";
                u[19] = c.charAt(Math.random() * 4 | 0);
                return u.join("");
            })();
            return {
                toString: function () {
                    return uuid;
                },
                valueOf: function () {
                    return uuid;
                }
            };
        };


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
                var auvToken = $("#credentials-form input[name=auvToken]").val();

                /* Get us a session. */
                ajaxGetSession(configuration, mtid, segment, secret, auvToken);

                /* ajaxTokenize is async. We will come back here and exit.
                   That's why we needed to do event.preventDefault() above.
                 */
            });
        });

        function ajaxGetSession(configuration, mtid, segment, secret, auvToken) {
            var params = {
                "id": generateAjaxId(),
                "method": "get_session",
                "params": [{
                    "utcTimestamp": utcTimestamp(),
                    "configurationId": configuration,
                    "mtid": mtid,
                    "retention": "big-year",
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
                        // alert("We've experienced a processing error. Please try again.");
                        /* This would be a good place to log an error
                           using whatever error tracking system you have.

                           Never show the following alert in production.
                         */
                        alert(data['error']);
                    } else {
                        /* Load the embedded iFrame */
                        var sessionId = data['result']['sessionId'];
                        var target = "dev";
                        $('#embedded').attr(
                            'src',
                            '../embedded-detokenize.html?sessionID=' + sessionId +
                            '&vault_trace_uid=' + vault_trace_uid +
                            '&auvToken=' + auvToken);
                    };
                },
                error: function(jqXHR, textStatus, errorThrown) {
                    // Another good place to log an error.
                    // alert("We've experienced a processing error. Please try again.");
                    // Never show alert in production.
                    alert(errorThrown);
                },
            });
        }




var embeddedDeTokenizer = document.getElementById("embedded");

//send message to iframe
var sendMessage = function(msg) {
    embeddedDeTokenizer.contentWindow.postMessage(msg, "*");
}
function bindEvent(element, eventName, eventHandler) {
    if (element.addEventListener){
        element.addEventListener(eventName, eventHandler, false);
    } else if (element.attachEvent) {
        element.attachEvent('on' + eventName, eventHandler);
    }
}

var messages = document.getElementById("messages");
bindEvent(window, "message", function(e){
   // console.log(e.data);
    var tag = e.data.tag || "";
    var data = e.data.data;

    if (tag == "auv_decrypted"){
        auv_decrypted();
    } else if (tag == "auv_error"){
        auv_error(data.code, data.message);
    } else if (tag == "auv_timeout"){
        auv_timeout();
    }
})

function show_auv_message(msg){
    // console.log(msg);
    alert(msg);
}
// API callback functions
function auv_decrypted(){
    show_auv_message("Decrypted the AuricVault® token.");
}

function auv_timeout(){
    show_auv_message("The AuricVault® service request timed out.");
}
function auv_error(error_code, error_message){
    var msg = "The AuricVault® service request failed. Code: " + error_code + ", error: " + error_message;
    show_auv_message(msg);
}
