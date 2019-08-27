{-# LANGUAGE OverloadedStrings #-}
module Message where

import           Data.Avro
import           Data.Avro.Schema
import qualified Data.Avro.Types               as AT
import           Data.Int
import           Data.Text

data TestMessage = TestMessage Text deriving (Show, Eq, Ord)

testMessageSchema =
    let fld nm = Field nm [] Nothing Nothing
    in  Record (TN "TestMessage" ["hw", "kafka", "avro", "test"])
               []
               Nothing
               Nothing
               [fld "created_at" String Nothing]

instance HasAvroSchema TestMessage where
    schema = pure testMessageSchema

instance FromAvro TestMessage where
    fromAvro (AT.Record _ r) = TestMessage <$> r .: "created_at"
    fromAvro v               = badValue v "TestMessage"
