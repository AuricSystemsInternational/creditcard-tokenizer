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
