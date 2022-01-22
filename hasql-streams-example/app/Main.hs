{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE DisambiguateRecordFields #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

module Main where

import Control.Monad
import Control.Monad.IO.Unlift
import Control.Monad.Trans.Resource
import Control.Monad.Error.Class
import Data.Function
import Data.Foldable
import Data.Int
import Data.Text
import Hasql.Connection
import qualified Hasql.Decoders as Decoders
import Hasql.Encoders
import Hasql.Session
import Hasql.Statement
import Hasql.Transaction
import qualified Hasql.Transaction.Sessions as Transaction
import Hasql.TH
import GHC.Generics

import Hasql.TransactionIO
import Hasql.TransactionIO.Sessions
import Hasql.CursorTransactionIO
import Hasql.CursorTransactionIO.TransactionIO

import Hasql.Conduit
import Hasql.Streamly
import Hasql.Streaming
import Hasql.Pipes

import qualified Streamly.Prelude as Streamly
import Streaming hiding (run)
import qualified Streaming.Prelude as Streaming
import Conduit
import qualified Data.Conduit.Combinators as Conduit
import Pipes hiding (each)
import qualified Pipes.Prelude as Pipes

import Rel8

data Author f = Author
  { authorId :: Column f AuthorId
  , name :: Column f Text
  , url :: Column f (Maybe Text)
  }
  deriving stock (Generic)
  deriving anyclass (Rel8able)

deriving stock instance f ~ Result => Show (Author f)
deriving stock instance f ~ Result => Show (Project f)

newtype AuthorId = AuthrId { toInt64 :: Int64 }
  deriving newtype (DBEq, DBType, Eq, Show)

data Project f = Project
  { projectAuthorId :: Column f AuthorId
  , projectName :: Column f Text
  }
  deriving stock (Generic)
  deriving anyclass (Rel8able)

authorSchema :: TableSchema (Author Name)
authorSchema = TableSchema
  { name = "author"
  , schema = Nothing
  , columns = Author
    { authorId = "author_id"
    , name = "name"
    , url = "url"
    }
  }

projectSchema :: TableSchema (Project Name)
projectSchema = TableSchema
  { name = "project"
  , schema = Nothing
  , columns = Project
    { projectAuthorId = "author_id"
    , projectName = "name"
    }
  }


main :: IO ()
main = do
  let config = settings "localhost" 5432 "postgres" "password" "postgres"
  conn <- either (error . show) id <$> acquire config
  res <- flip run conn $ do
    Transaction.transaction Transaction.ReadCommitted Transaction.Write $ Hasql.Transaction.sql [uncheckedSql|
      drop table if exists author cascade;
      create table author (
        author_id integer not null,
        name text not null,
        url text,
        primary key(author_id)
      );
      insert into author values
        (1, 'Ollie'),
        (2, 'Bryan O''Sullivan'),
        (3, 'Emily Pilmore');
      drop table if exists project cascade;
      create table project (
        author_id integer not null,
        name text not null,
        constraint fk_author foreign key(author_id) references author(author_id)
      );
      insert into project values
        (1, 'rel8'),
        (2, 'aeson'),
        (2, 'text');
    |]
    let stmt = select (each projectSchema)
    -- io
    Hasql.Session.statement () stmt >>= mapM_ (liftIO . print)
    -- streamly
    transactionIO ReadCommitted ReadOnly NotDeferrable $
      cursorTransactionIO $
        streamlyQuery stmt ()
          & Streamly.mapM_ (liftIO . print)
    -- streaming
    transactionIO ReadCommitted ReadOnly NotDeferrable $
      cursorTransactionIO $
        streamingQuery stmt ()
          & Streaming.mapM_ (liftIO . print)
    -- conduit
    transactionIO ReadCommitted ReadOnly NotDeferrable $
      cursorTransactionIO $
        conduitQuery stmt ()
          .| Conduit.mapM_ (liftIO . print)
          & runConduit
    -- pipes
    transactionIO ReadCommitted ReadOnly NotDeferrable $
      cursorTransactionIO $
        pipesQuery stmt ()
          >-> Pipes.mapM_ (liftIO . print)
          & runEffect
    -- concurrent cursors
    transactionIO ReadCommitted ReadOnly NotDeferrable $ do
      cursorTransactionIO $ do
        cursor1 <- declareCursorFor () stmt
        cursor2 <- declareCursorFor () stmt
        let 
          loop = do
            batch1 <- fetchWithCursor cursor1
            batch2 <- fetchWithCursor cursor2
            unless (Prelude.null batch1 && Prelude.null batch2) $ do
              liftIO $ print batch1
              liftIO $ print batch2
              loop
        loop
    -- concurrent streams
    transactionIO ReadCommitted ReadOnly NotDeferrable $
      cursorTransactionIO $ do
        let s = streamlyQuery stmt ()
        Streamly.zipWith (,) s s
          & Streamly.mapM_ (liftIO . print)
  print res
