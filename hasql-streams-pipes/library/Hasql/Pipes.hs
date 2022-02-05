module Hasql.Pipes (
  pipesQuery,
) where

-- transformers
import Control.Monad.Trans.Class

-- pipes
import Pipes
import qualified Pipes.Prelude as Pipes

-- hasql
import Hasql.Statement

-- hasql-transaction-io
import Hasql.CursorTransactionIO

-- hasql-streams-core
import Hasql.Streams

-- | Run a `Statement` using a cursor to return a `Producer` instead of a list
pipesQuery :: Statement params [a] -> params -> Producer a (CursorTransactionIO s) ()
pipesQuery stmt params = cursorStreamQuery stmt params foldPipesStream

foldPipesStream :: CursorStreamFold s a (Producer a (CursorTransactionIO s) ())
foldPipesStream step init = lift init >>= Pipes.unfoldr (fmap maybeToEither . step)

maybeToEither :: Maybe a -> Either () a
maybeToEither = maybe (Left ()) Right
