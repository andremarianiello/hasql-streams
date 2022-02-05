{-# LANGUAGE OverloadedStrings #-}

module Hasql.Streams (
  CursorStreamFold,
  cursorStreamQuery,
) where

-- hasql
import Hasql.Statement

-- hasql-transaction-io
import Hasql.CursorTransactionIO as CursorTransactionIO

-- | A fold over a stream of @a@ values to produce an @r@ using @CursorTransactionIO s@
type CursorStreamFold s a r = 
  (forall x. 
    (x -> CursorTransactionIO s (Maybe (a, x))) ->
    CursorTransactionIO s x ->
    r
  )

-- | Run a `Statement` using a cursor inside a `CursorTransactionIO` to produce a stream of @a@s, which are consumed by a `CursorStreamFold`. This function can produce any type of stream without depending on any particular stream library.
cursorStreamQuery :: forall params s a r.
  Statement params [a] -> params -> CursorStreamFold s a r -> r
cursorStreamQuery stmt params foldStream = foldStream step init
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

type StreamState s a = (Cursor s [a], [a])
