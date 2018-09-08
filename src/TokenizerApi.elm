-- Copyright (c) 2017-2018 Auric Systems International. All rights reserved.
-- License: 3-Clause BSD License. See accompanying LICENSE file.


port module TokenizerApi
    exposing
        ( IncomingMessage(..)
        , OutgoingMessage(..)
        , Token
        , getIncomingMessage
        , sendMessageOut
        )

import CreditCardValidator as CCV
import Json.Decode as JD
import Json.Encode as JE


type alias Token =
    String


type alias ErrorCode =
    String


type alias ErrorMessage =
    String


type OutgoingMessage
    = Auv_OK Token CCV.CardType
    | Auv_Timeout
    | Auv_Error ErrorCode ErrorMessage
    | LogError String -- for all general non Auv errors
    | CreditCardValid String Bool


type IncomingMessage
    = Tokenize
    | IsCreditCardValid String


type alias ApiMessage =
    { tag : String
    , data : JE.Value
    }



{- All outgoing messages -}


port outgoing : ApiMessage -> Cmd msg


port incoming : (ApiMessage -> msg) -> Sub msg


encodeCardType : CCV.CardType -> JE.Value
encodeCardType cardType =
    case cardType of
        CCV.AM ->
            JE.string "AM"

        CCV.DS ->
            JE.string "DS"

        CCV.MC ->
            JE.string "MC"

        CCV.VI ->
            JE.string "VI"

        CCV.DC ->
            JE.string "DC"

        CCV.UK ->
            JE.string "UK"


encodeAuvOkData : Token -> CCV.CardType -> JE.Value
encodeAuvOkData token cardType =
    JE.object
        [ ( "token", JE.string token )
        , ( "cardType", encodeCardType cardType )
        ]


encodeAuvErrorData : ErrorCode -> ErrorMessage -> JE.Value
encodeAuvErrorData errorCode errorMessage =
    JE.object
        [ ( "code", JE.string errorCode )
        , ( "message", JE.string errorMessage )
        ]


encodeCCValidData : String -> Bool -> JE.Value
encodeCCValidData requestId valid =
    JE.object
        [ ( "requestId", JE.string requestId )
        , ( "isValid", JE.bool valid )
        ]


sendMessageOut : OutgoingMessage -> Cmd msg
sendMessageOut info =
    case info of
        Auv_OK token cardType ->
            outgoing { tag = "auv_ok", data = encodeAuvOkData token cardType }

        Auv_Timeout ->
            outgoing { tag = "auv_timeout", data = JE.null }

        Auv_Error errorCode errorMessage ->
            outgoing { tag = "auv_error", data = encodeAuvErrorData errorCode errorMessage }

        LogError err ->
            outgoing { tag = "log_error", data = JE.string err }

        CreditCardValid requestId valid ->
            outgoing { tag = "cc_valid", data = encodeCCValidData requestId valid }


getIncomingMessage : (IncomingMessage -> msg) -> (String -> msg) -> Sub msg
getIncomingMessage tagger onError =
    incoming
        (\externalInfo ->
            case externalInfo.tag of
                "tokenize" ->
                    tagger Tokenize

                "isCreditCardValid" ->
                    tagger
                        (IsCreditCardValid
                            (JD.decodeValue JD.string externalInfo.data
                                |> Result.withDefault ""
                            )
                        )

                _ ->
                    onError <| "Unexpected external message for " ++ externalInfo.tag
        )
