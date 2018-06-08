-- Copyright (c) 2017-2018 Auric Systems International. All rights reserved.
-- License: 3-Clause BSD License. See accompanying LICENSE file.


module Auv exposing (..)

import Http
import Json.Decode as JD
import Json.Decode.Pipeline as JDP
import Navigation as Nav
import Time


type TargetEnvironment
    = Dev
    | Test
    | Prod


mapEnvironment : Maybe String -> TargetEnvironment
mapEnvironment target =
    case target of
        Nothing ->
            Prod

        Just env ->
            if String.trim env == "dev" then
                Dev
            else if String.trim env == "test" then
                Test
            else
                Prod



-- Talk to the vault from which we were loaded.
-- Talk to sandbox if running outside a vault (probably dev environment).


vault_url : Nav.Location -> String
vault_url location =
    let
        url_fragment =
            "/vault/v2/"
    in
    if String.startsWith "vault0" location.host then
        "https://" ++ location.host ++ url_fragment
    else
        "https://vault01-sb.auricsystems.com" ++ url_fragment


type alias DetokenizeResult =
    { version : String
    , lastActionSucceeded : Int
    , plaintextValue : String
    , elapsedTime : String
    }


type alias DetokenizeResponsePayload =
    { id : Int
    , result : DetokenizeResult
    , error : String
    }


deTokenResultDecoder : JD.Decoder DetokenizeResult
deTokenResultDecoder =
    JDP.decode DetokenizeResult
        |> JDP.required "version" JD.string
        |> JDP.required "lastActionSucceeded" JD.int
        |> JDP.optional "plaintextValue" JD.string ""
        |> JDP.required "elapsedTime" JD.string


deTokenizeResponsePayloadDecoder : JD.Decoder DetokenizeResponsePayload
deTokenizeResponsePayloadDecoder =
    JDP.decode DetokenizeResponsePayload
        |> JDP.required "id" JD.int
        |> JDP.required "result" deTokenResultDecoder
        |> JDP.optional "error" JD.string ""


type alias TokenizeResult =
    { version : String
    , lastActionSucceeded : Int
    , token : String
    , elapsedTime : String
    }


type alias TokenizeResponsePayload =
    { id : Int
    , result : TokenizeResult
    , error : String
    }


tokenResultDecoder : JD.Decoder TokenizeResult
tokenResultDecoder =
    JDP.decode TokenizeResult
        |> JDP.required "version" JD.string
        |> JDP.required "lastActionSucceeded" JD.int
        |> JDP.optional "token" JD.string ""
        |> JDP.required "elapsedTime" JD.string


tokenizeResponsePayloadDecoder : JD.Decoder TokenizeResponsePayload
tokenizeResponsePayloadDecoder =
    JDP.decode TokenizeResponsePayload
        |> JDP.required "id" JD.int
        |> JDP.required "result" tokenResultDecoder
        |> JDP.optional "error" JD.string ""


post : String -> List Http.Header -> Http.Body -> JD.Decoder a -> Http.Request a
post url headers body decoder =
    Http.request
        { method = "POST"
        , headers = headers
        , url = url
        , body = body
        , expect = Http.expectJson decoder
        , timeout = Just (10 * Time.second)
        , withCredentials = False
        }
