-- Copyright (c) 2017-2018 Auric Systems International. All rights reserved.
-- License: 3-Clause BSD License. See accompanying LICENSE file.


port module DetokenizerApi
    exposing
        ( DetokenizeOutgoingMessage(..)
        , sendMessageOut
        )

import Json.Encode as JE


type alias ErrorCode =
    String


type alias ErrorMessage =
    String


type alias ApiMessage =
    { tag : String
    , data : JE.Value
    }


type DetokenizeOutgoingMessage
    = Auv_Decrypted
    | Auv_Timeout
    | Auv_Error ErrorCode ErrorMessage
    | LogError String -- for all general non Auv errors


port outgoing : ApiMessage -> Cmd msg


port incoming : (ApiMessage -> msg) -> Sub msg


encodeAuvErrorData : ErrorCode -> ErrorMessage -> JE.Value
encodeAuvErrorData errorCode errorMessage =
    JE.object
        [ ( "code", JE.string errorCode )
        , ( "message", JE.string errorMessage )
        ]


sendMessageOut : DetokenizeOutgoingMessage -> Cmd msg
sendMessageOut info =
    case info of
        Auv_Timeout ->
            outgoing { tag = "auv_timeout", data = JE.null }

        Auv_Error errorCode errorMessage ->
            outgoing { tag = "auv_error", data = encodeAuvErrorData errorCode errorMessage }

        LogError err ->
            outgoing { tag = "log_error", data = JE.string err }

        Auv_Decrypted ->
            outgoing { tag = "auv_decrypted", data = JE.null }
