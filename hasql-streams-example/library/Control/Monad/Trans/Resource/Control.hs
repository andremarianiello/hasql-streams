{-# LANGUAGE UndecidableInstances #-}

module Control.Monad.Trans.Resource.Control where

-- transformers
import Control.Monad.Trans.Class
import Control.Monad.Trans.Reader

-- transformers-base
import Control.Monad.Base

-- monad-control
import Control.Monad.Trans.Control

-- resourcet
import Control.Monad.Trans.Resource

fromResourceT :: ResourceT m a -> ReaderT InternalState m a
fromResourceT = ReaderT . runInternalState

toResourceT :: ReaderT InternalState m a -> ResourceT m a
toResourceT = withInternalState . runReaderT

instance MonadBase b m => MonadBase b (ResourceT m) where
  liftBase = lift . liftBase

instance MonadTransControl ResourceT where
  type StT ResourceT a = a
  liftWith = defaultLiftWith toResourceT fromResourceT
  restoreT = defaultRestoreT toResourceT

instance MonadBaseControl b m => MonadBaseControl b (ResourceT m) where
  type StM (ResourceT m) a = ComposeSt ResourceT m a
  liftBaseWith = defaultLiftBaseWith
  restoreM = defaultRestoreM
