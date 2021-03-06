{-# LANGUAGE OverloadedStrings #-}
module Environment where

import qualified Data.ByteString.Char8 as BS
import Data.Char (isUpper,isSymbol,isAlpha,isDigit)
import qualified Data.List as List
import qualified Data.Map as Map

data Repl = Repl
    { compilerPath :: FilePath
    , flags :: [String]
    , imports :: Map.Map String String
    , adts :: Map.Map String String
    , defs :: Map.Map String String
    } deriving Show

empty :: FilePath -> Repl
empty compilerPath =
    Repl compilerPath [] Map.empty Map.empty (Map.singleton "t_s_o_l_" "t_s_o_l_ = ()")

output :: BS.ByteString
output = "deltron3030"

toElm :: Repl -> String
toElm env = unlines $ "module Repl where" : decls
    where decls = concatMap Map.elems [ imports env, adts env, defs env ]

insert :: String -> Repl -> Repl
insert str env
    | List.isPrefixOf "import " str = 
        let name = getFirstCap (words str)
            getFirstCap (token@(c:_):rest) =
                if isUpper c then token else getFirstCap rest
            getFirstCap _ = str
        in  noDisplay $ env { imports = Map.insert name str (imports env) }

    | List.isPrefixOf "data " str =
        let name = takeWhile (/=' ') (drop 5 str)
        in  noDisplay $ env { adts = Map.insert name str (adts env) }
            
    | otherwise =
        case break (=='=') str of
          (_,"") -> display str env
          (beforeEquals, _:c:_)
              | isSymbol c || hasLet beforeEquals || hasBrace beforeEquals -> display str env
              | otherwise -> let name = declName beforeEquals
                             in  define name str (display name env)
          _ -> error "Environment.hs: Case error. Submit bug report."
        where
          declName pattern =
              case takeWhile isSymbol . dropWhile (not . isSymbol) $ pattern of
                "" -> takeWhile (/=' ') pattern
                op -> op

          hasLet = elem "let" . map token . words
              where
                isVarChar c = isAlpha c || isDigit c || elem c "_'"
                token = takeWhile isVarChar . dropWhile (not . isAlpha)

          hasBrace = elem '{'

define :: String -> String -> Repl -> Repl
define name body env = env { defs = Map.insert name body (defs env) }

display :: String -> Repl -> Repl
display = define output' . format
    where format body = output' ++ " =" ++ concatMap ("\n  "++) (lines body)
          output' = BS.unpack output

noDisplay :: Repl -> Repl
noDisplay env = env { defs = Map.delete output' (defs env) }
    where output' = BS.unpack output
