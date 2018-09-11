module Helpers exposing (..)

import Http
import Time


{-| Just return the raw error string
-}
httpErrorToString : Http.Error -> String
httpErrorToString error =
    case error of
        Http.BadUrl url ->
            url

        Http.Timeout ->
            "Timeout"

        Http.NetworkError ->
            "Network error"

        Http.BadStatus response ->
            response.body

        Http.BadPayload str1 _ ->
            str1


toSeconds : Time.Posix -> Int
toSeconds time =
    Time.posixToMillis time // 1000


isNotAscii : Char.Char -> Bool
isNotAscii char =
    let
        code =
            Char.toCode char
    in
    code < 0x20 || code > 0x7E


isNothingOrEmpty : Maybe String -> Bool
isNothingOrEmpty str =
    case str of
        Nothing ->
            True

        Just val ->
            String.isEmpty val


{-| Validates that it's possible to send tokenization request. Returns list of error messages if any
-}
validateCommonParameters : { a | sessionID : Maybe String, vaultTraceId : Maybe String } -> List String
validateCommonParameters { sessionID, vaultTraceId } =
    let
        sessionIDErrors =
            if isNothingOrEmpty sessionID then
                [ "Missing parameter: SessionID" ]
            else
                []

        traceId =
            vaultTraceId |> Maybe.withDefault ""

        traceIdErrors =
            List.concat
                [ if isNothingOrEmpty (Just traceId) then
                    [ "Missing parameter: vault_trace_uid" ]
                  else
                    []
                , if String.length traceId > 64 then
                    [ "vault_trace_uid cannot be larger than 64 characters" ]
                  else
                    []
                , if traceId |> String.toList |> List.any isNotAscii then
                    [ "vault_trace_uid can only contain printable ASCII characters" ]
                  else
                    []
                ]
    in
    sessionIDErrors ++ traceIdErrors
