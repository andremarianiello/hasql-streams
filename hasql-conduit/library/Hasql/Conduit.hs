module Hasql.Conduit (
  conduitQuery,
) where

-- transformers
import Control.Monad.Trans.Class

-- conduit
import Data.Conduit
import Data.Conduit.List

-- hasql
import Hasql.Statement

-- hasql-transaction-io
import Hasql.CursorTransactionIO

-- hasql-streams-core
import Hasql.Streams

-- | Run a `Statement`, but return a `Conduit` instead of a list
conduitQuery :: Statement params [a] -> params ->
  ConduitT () a (CursorTransactionIO s) ()
conduitQuery stmt params = cursorStreamQuery stmt params foldConduitStream

foldConduitStream :: CursorStreamFold s a (ConduitT () a (CursorTransactionIO s) ())
foldConduitStream step init = lift init >>= unfoldM step
