{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
module ConsumerExample where

import           Control.Monad.Trans.Except
import           Control.Arrow                  ( (&&&)
                                                , left
                                                )
import           Control.Exception              ( bracket )
import           Data.Monoid                    ( (<>) )
import           Kafka.Consumer
import           Data.Text                      ( Text )
import qualified Data.Aeson                    as J
import qualified Data.Avro                     as A
import           Data.Avro.Schema              as S
import qualified Data.Avro.Types               as AT

import           Data.Int
import           Kafka.Avro
import           Message
import qualified Data.ByteString               as B
import qualified Data.ByteString.Internal      as BI
import qualified Data.ByteString.Lazy          as BL
import qualified Data.ByteString.Lazy.Internal as BLI
import           Data.ByteString.Lazy.Char8     ( fromStrict )

data AppError = EncError EncodeError | DecError DecodeError
  deriving (Show)

brokerAddress :: Text
brokerAddress = "myBrokerAdress"

-- Global consumer properties
consumerProps :: ConsumerProperties
consumerProps =
    brokersList [BrokerAddress brokerAddress]
        <> groupId (ConsumerGroupId "consumer_example_group")
        <> noAutoCommit
        <> setCallback (rebalanceCallback printingRebalanceCallback)
        <> setCallback (offsetCommitCallback printingOffsetCallback)
        <> logLevel KafkaLogInfo

-- Subscription to topics
consumerSub :: Subscription
consumerSub = topics [TopicName "biz-limoges"] <> offsetReset Earliest

-- Running an example
runConsumerExample :: IO ()
runConsumerExample = do
    print $ cpLogLevel consumerProps
    res <- bracket mkConsumer clConsumer runHandler
    print res
  where
    mkConsumer = newConsumer consumerProps consumerSub
    clConsumer (Left  err) = return (Left err)
    clConsumer (Right kc ) = (maybe (Right ()) Left) <$> closeConsumer kc
    runHandler (Left  err) = return (Left err)
    runHandler (Right kc ) = processMessages kc

-------------------------------------------------------------------
processMessages :: KafkaConsumer -> IO (Either KafkaError ())
processMessages kafka = do
    sr <- schemaRegistry "https://avro-registry.internal.stuart.com/"
    mapM_
        (\_ -> do
            msg1 <- pollMessage kafka (Timeout 1000)
            -- fe   <- pure $ filterEmpty msg1
            putStrLn
                $ "Message:==================================================+> "
                <> show msg1
            -- putStrLn $ show (getFlob sr msg1)
            -- putStrLn $ getFlob msg1
            err <- commitAllOffsets OffsetCommit kafka
            putStrLn $ "Offsets: " <> maybe "Committed." show err
        )
        [0 :: Integer .. 10000]
    return $ Right ()

-- filterEmpty
--     :: Either
--            KafkaError
--            (ConsumerRecord (Maybe BI.ByteString) (Maybe BI.ByteString))
--     -> SchemaRegistry
--     -> Either String TestMessage
-- filterEmpty (Right (ConsumerRecord topicName _ _ _ (Just key) (Just value))) sr
--     = case decodeWithSchema sr (fromStrict key) of
--         Left  _ -> Left "decoding error, but what ? no i wont tell"
--         Right v -> undefined
-- filterEmpty _ _ = Left "we re fucked fucked"

toStrict1 :: BL.ByteString -> B.ByteString
toStrict1 = B.concat . BL.toChunks

printingRebalanceCallback :: KafkaConsumer -> RebalanceEvent -> IO ()
printingRebalanceCallback _ e = case e of
    RebalanceBeforeAssign ps ->
        putStrLn $ "[Rebalance] About to assign partitions: " <> show ps
    RebalanceAssign ps ->
        putStrLn $ "[Rebalance] Assign partitions: " <> show ps
    RebalanceBeforeRevoke ps ->
        putStrLn $ "[Rebalance] About to revoke partitions: " <> show ps
    RebalanceRevoke ps ->
        putStrLn $ "[Rebalance] Revoke partitions: " <> show ps

printingOffsetCallback
    :: KafkaConsumer -> KafkaError -> [TopicPartition] -> IO ()
printingOffsetCallback _ e ps = do
    print ("Offsets callback:" ++ show e)
    mapM_ (print . (tpTopicName &&& tpPartition &&& tpOffset)) ps

