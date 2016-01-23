module Form.Validate
  ( Validation, get, map, succeed, andThen, pipeTo, customError, defaultValue
  , (:=), (?=), (|:)
  , form1, form2, form3, form4, form5, form6, form7, form8
  , string, int, float, bool, date, maybe
  , minInt, maxInt, minLength, maxLength, nonEmpty
  ) where

import Result
import Date exposing (Date)
import Dict exposing (Dict)
import String

import Form.Error as Error exposing (Error(..))
import Form.Field as Field exposing (Field(..))


{-| A validation is a function that takes a form field and returns a result
being either a validation error or the expected object.
-}
type alias Validation customError output =
  Field -> Result (Error customError) output


{-| Map over the result of the validation.

    string `map` String.trim
-}
map : (a -> b) -> Validation e a -> Validation e b
map f validation =
  \field -> Result.map f (validation field)


{-| Apply a new validation to the result of the validation.

    int `andThen` (minInt 10)
-}
andThen : Validation e a -> (a -> Validation e b) -> Validation e b
andThen validation callback =
  \field -> validation field `Result.andThen` (\next -> (callback next) field)


{-| Same as `andThen`, but flipped for piping.

    int |> pipeTo (minInt 5)
-}
pipeTo : (a -> Validation e b) -> Validation e a -> Validation e b
pipeTo =
  flip andThen


succeed : a -> Validation e a
succeed a field =
  Ok a


apply : Validation e (a -> b) -> Validation e a -> Validation e b
apply partialValidation aValidation field =
  case (partialValidation field, aValidation field) of
    (Ok partial, Ok a) ->
      Ok (partial a)
    (partialResult, aResult) ->
      Err (mergeMany [ getErr partialResult, getErr aResult ])

(|:) = apply


defaultValue : a -> Validation e a -> Validation e a
defaultValue a validation field =
  Ok (Result.withDefault a (validation field))


{-| Call Result.formatError on validation result. -}
formatError : (Error e -> Error e) -> Validation e a -> Validation e a
formatError f validation =
  \field -> Result.formatError f (validation field)


{-| Transform validation error to the provided custom error. -}
customError : e -> Validation e a -> Validation e a
customError e =
  formatError (\_ -> CustomError e)


{-| private -}
groupError : String -> Error e -> Error e
groupError name e =
  GroupErrors <| Dict.fromList [ (name, e) ]


{-| private -}
err : Error e -> Result (Error e) a
err e =
  Err e


{-| private -}
ifErr : Error e -> Result e' a -> Result (Error e) a
ifErr e res =
  Result.formatError (\_ -> e) res


{-| get "name" string -}
get : String -> Validation e a -> Validation e a
get key validation =
  let
    func v = case v of
      Group fields ->
        case Dict.get key fields of
          Just a -> validation a |> Result.formatError (\e -> groupError key e)
          Nothing -> Err (groupError key EmptyError)
      _ ->
        Err (groupError key EmptyError)
  in
    func


{-| Validate field.

    "name" := string
-}
(:=) : String -> Validation e a -> Validation e a
(:=) =
  get

{-| Validate field, wrapped in a `maybe` (Nothing if error).

    "hobby" ?= string
-}
(?=) : String -> Validation e a -> Validation e (Maybe a)
(?=) s v =
  maybe (get s v)

{-| Validate a form with one field. -}
form1 : (a -> field) -> Validation e a -> Validation e field
form1 =
  map


{-| Validate a form with two fields. -}
form2 : (a -> b -> m) -> Validation e a -> Validation e b -> Validation e m
form2 func v1 v2 =
  (form1 func v1) `apply` v2


{-| Validate a form with three fields. -}
form3 : (a -> b -> c -> m) -> Validation e a -> Validation e b -> Validation e c -> Validation e m
form3 func v1 v2 v3 =
  (form2 func v1 v2) `apply` v3


{-| Validate a form with four fields. -}
form4 : (a -> b -> c -> d -> m) -> Validation e a -> Validation e b -> Validation e c -> Validation e d -> Validation e m
form4 func v1 v2 v3 v4 =
  (form3 func v1 v2 v3) `apply` v4


{-| Validate a form with five fields. -}
form5 : (a -> b -> c -> d -> e -> m) -> Validation err a -> Validation err b -> Validation err c -> Validation err d -> Validation err e -> Validation err m
form5 func v1 v2 v3 v4 v5 =
  (form4 func v1 v2 v3 v4) `apply` v5


{-| Validate a form with six fields. -}
form6 : (a -> b -> c -> d -> e -> f -> m) -> Validation err a -> Validation err b -> Validation err c -> Validation err d -> Validation err e -> Validation err f -> Validation err m
form6 func v1 v2 v3 v4 v5 v6 =
  (form5 func v1 v2 v3 v4 v5) `apply` v6


{-| Validate a form with seven fields. -}
form7 : (a -> b -> c -> d -> e -> f -> g -> m) -> Validation err a -> Validation err b -> Validation err c -> Validation err d -> Validation err e -> Validation err f -> Validation err g -> Validation err m
form7 func v1 v2 v3 v4 v5 v6 v7 =
  (form6 func v1 v2 v3 v4 v5 v6) `apply` v7


{-| Validate a form with eight fields. -}
form8 : (a -> b -> c -> d -> e -> f -> g -> h -> m) -> Validation err a -> Validation err b -> Validation err c -> Validation err d -> Validation err e -> Validation err f -> Validation err g -> Validation err h -> Validation err m
form8 func v1 v2 v3 v4 v5 v6 v7 v8 =
  (form7 func v1 v2 v3 v4 v5 v6 v7) `apply` v8


{-| Private -}
mergeMany : List (Maybe (Error e)) -> Error e
mergeMany errors =
  errors
    |> List.filterMap identity
    |> List.foldl groupErrorsUnion (GroupErrors Dict.empty)


{-| Private -}
groupErrorsUnion : Error e -> Error e -> Error e
groupErrorsUnion e1 e2 =
  case (e1, e2) of
    (GroupErrors ge1, GroupErrors ge2) ->
      GroupErrors (Dict.union ge1 ge2)
    _ ->
      e2


{-| Private -}
getErr : Result e a -> Maybe e
getErr res =
  case res of
    Ok _ -> Nothing
    Err e -> Just e


{-| Validate an integer using `String.toInt`. -}
int : Validation e Int
int v =
  case v of
    Text s ->
      String.toInt s |> ifErr InvalidInt
    _ ->
      err InvalidInt


{-| Validate a float using `String.toFloat`. -}
float : Validation e Float
float v =
  case v of
    Text s ->
      String.toFloat s |> ifErr InvalidFloat
    _ ->
      err InvalidInt


{-| Validate a String. -}
string : Validation e String
string v =
  case v of
    Text s ->
      if String.isEmpty s then
        Err EmptyError
      else
        Ok s
    _ ->
      err InvalidString


{-| Validate a Bool. -}
bool : Validation e Bool
bool v =
  case v of
    Check b ->
      Ok b
    _ ->
      Ok False


{-| Validate a Date using `Date.fromString`. -}
date : Validation e Date
date v =
  case v of
    Text s ->
      Date.fromString s |> ifErr InvalidDate
    _ ->
      err InvalidDate


{-| Transform validation result to `Maybe`, using `Result.toMaybe`. -}
maybe : Validation e a -> Validation e (Maybe a)
maybe validation field =
  Ok (Result.toMaybe (validation field))


{-| Fails if `String.isEmpty`. -}
nonEmpty : String -> Validation e String
nonEmpty s field =
  if String.isEmpty s then
    err EmptyError
  else
    Ok s


{-| Min length for String. -}
minLength : Int -> String -> Validation e String
minLength min s field =
  if String.length s >= min then
    Ok s
  else
    err (ShorterThan min)


{-| Max length for String. -}
maxLength : Int -> String -> Validation e String
maxLength max s field =
  if String.length s <= max then
    Ok s
  else
    err (ShorterThan max)


{-| Min field for Int. -}
minInt : Int -> Int -> Validation e Int
minInt min i =
  \field -> if i >= min then Ok i else err (SmallerThan min)


{-| Max field for Int. -}
maxInt : Int -> Int -> Validation e Int
maxInt max i =
  \field -> if i <= max then Ok i else err (GreaterThan max)