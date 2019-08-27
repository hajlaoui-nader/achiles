{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
module ConsumerExample where

import           Control.Arrow                  ( (&&&) )
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
-- Global consumer properties
consumerProps :: ConsumerProperties
consumerProps =
    brokersList
            [BrokerAddress "livealerting-services-1.prod.eu-west-1.stuart:9092"]
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
    sr  <- schemaRegistry "http://localhost:8081"
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
    mapM_
        (\_ -> do
            msg1 <- pollMessage kafka (Timeout 1000)
            putStrLn $ "Message: " <> show msg1
            err <- commitAllOffsets OffsetCommit kafka
            putStrLn $ "Offsets: " <> maybe "Committed." show err
        )
        [0 :: Integer .. 1000]
    return $ Right ()

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
