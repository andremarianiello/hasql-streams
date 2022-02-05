module Hasql.Streaming (
  streamingQuery,
) where

-- streaming
import Streaming
import Streaming.Prelude as Streaming

-- hasql
import Hasql.Statement

-- hasql-transaction-io
import Hasql.CursorTransactionIO

-- hasql-streaming
import Hasql.Streams

-- | Run a `Statement` using a cursor to return a `Stream` instead of a list
streamingQuery :: 
  Statement params [a] -> params ->
  Stream (Of a) (CursorTransactionIO s) ()
streamingQuery stmt params = cursorStreamQuery stmt params foldStreamingStream

foldStreamingStream ::
  CursorStreamFold s a (Stream (Of a) (CursorTransactionIO s) ())
foldStreamingStream step init = lift init >>= Streaming.unfoldr (fmap maybeToEither . step)

maybeToEither :: Maybe a -> Either () a
maybeToEither = maybe (Left ()) Right
