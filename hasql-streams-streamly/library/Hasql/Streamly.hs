module Hasql.Streamly (
  streamlyQuery,
) where

-- transformers
import Control.Monad.Trans.Class

-- streamly
import qualified Streamly.Prelude as Streamly
import qualified Streamly.Internal.Data.Stream.Serial as Serial

-- hasql
import Hasql.Statement

-- hasql-transaction-io
import Hasql.CursorTransactionIO

-- hasql-streams-core
import Hasql.Streams

-- | Run a `Statement` using a cursor to return an instance of `Streamly.IsStream` instead of a list
streamlyQuery ::
  (Streamly.IsStream t) => 
  Statement params [a] -> params -> t (CursorTransactionIO s) a
streamlyQuery stmt params = cursorStreamQuery stmt params foldStreamlyStream

foldStreamlyStream ::
  (Streamly.IsStream t) =>
  CursorStreamFold s a (t (CursorTransactionIO s) a)
foldStreamlyStream step init = Streamly.adapt (lift init >>= Serial.unfoldrM step)
