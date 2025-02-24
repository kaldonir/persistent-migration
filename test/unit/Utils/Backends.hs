{-# LANGUAGE CPP #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}

module Utils.Backends
  ( MockDatabase(..)
  , defaultDatabase
  , setDatabase
  , withTestBackend
  ) where

import Control.Monad.IO.Class (liftIO)
import Data.Conduit.List (sourceList)
import Data.IORef (IORef, newIORef, readIORef, writeIORef)
import qualified Data.Map as Map
import Data.Maybe (maybeToList)
import Database.Persist.Migration (Version)
import Database.Persist.Sql (PersistValue(..), SqlBackend(..), Statement(..))
import System.IO.Unsafe (unsafePerformIO)

{- Mock test database -}

-- | The mock database backend for testing.
newtype MockDatabase = MockDatabase
  { version :: Maybe Version
  }

-- | The default test database.
defaultDatabase :: MockDatabase
defaultDatabase = MockDatabase Nothing

-- | The global test database.
mockDatabase :: IORef MockDatabase
mockDatabase = unsafePerformIO $ newIORef defaultDatabase
{-# NOINLINE mockDatabase #-}

-- | Set the test database.
setDatabase :: MockDatabase -> IO ()
setDatabase = writeIORef mockDatabase

{- Mock SqlBackend -}

-- | Initialize a mock SqlBackend for testing.
withTestBackend :: (SqlBackend -> IO a) -> IO a
withTestBackend action = do
  smap <- newIORef Map.empty
  action SqlBackend
    { connPrepare = \case
        "SELECT version FROM persistent_migration ORDER BY timestamp DESC LIMIT 1" ->
          return stmt
            { stmtQuery = \_ -> do
                MockDatabase{version} <- liftIO $ readIORef mockDatabase
                let result = pure . PersistInt64 . fromIntegral <$> maybeToList version
                return $ sourceList result
            }
        _ -> return stmt
    , connStmtMap = smap
    , connInsertSql = error "connInsertSql"
    , connUpsertSql = error "connUpsertSql"
    , connPutManySql = error "connPutManySql"
    , connInsertManySql = error "connInsertManySql"
    , connClose = error "connClose"
    , connMigrateSql = error "connMigrateSql"
    , connBegin = error "connBegin"
    , connCommit = error "connCommit"
    , connRollback = error "connRollback"
    , connEscapeName = error "connEscapeName"
    , connNoLimit = error "connNoLimit"
    , connRDBMS = error "connRDBMS"
    , connLimitOffset = error "connLimitOffset"
    , connLogFunc = \_ _ _ _ -> return ()
    , connMaxParams = error "connMaxParams"
#if MIN_VERSION_persistent(2, 9, 0)
    , connRepsertManySql = error "connRepsertManySql"
#endif
    }
  where
    stmt = Statement
      { stmtFinalize = return ()
      , stmtReset = return ()
      , stmtExecute = \_ -> return 0
      , stmtQuery = error "stmtQuery"
      }
