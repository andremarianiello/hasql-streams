{-# LANGUAGE OverloadedStrings #-}

module Hasql.Streams where

-- hasql
import Hasql.Statement

-- hasql-transaction-io
import Hasql.CursorTransactionIO as CursorTransactionIO

type StreamState s a = (Cursor s [a], [a])

type CursorStreamFold s a r = 
  (forall x. 
    (x -> CursorTransactionIO s (Maybe (a, x))) ->
    CursorTransactionIO s x ->
    r
  )

streamQuery :: forall params s a r.
  Statement params [a] -> params -> CursorStreamFold s a r -> r
streamQuery stmt params foldStream = foldStream step init
  where
    init :: CursorTransactionIO s (StreamState s a)
    init = do
      cursor <- declareCursorFor params stmt
      pure (cursor, [])
    step :: StreamState s a -> CursorTransactionIO s (Maybe (a, StreamState s a))
    step (cursor, batch) = case batch of
      (a:batch') -> pure $ Just (a, (cursor, batch'))
      [] -> do
        batch' <- fetchWithCursor cursor
        if Prelude.null batch'
        then pure Nothing
        else step (cursor, batch')
