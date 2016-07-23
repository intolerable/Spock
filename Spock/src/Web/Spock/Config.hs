{-# LANGUAGE OverloadedStrings #-}
module Web.Spock.Config
    ( SpockCfg (..), defaultSpockCfg
      -- * Database
    , PoolOrConn (..), ConnBuilder (..), PoolCfg (..)
      -- * Sessions
    , defaultSessionCfg, SessionCfg (..)
    , defaultSessionHooks, SessionHooks (..)
    , SessionStore(..), SessionStoreInstance(..)
    , SV.newStmSessionStore
    )
where

import Web.Spock.Action
import Web.Spock.Internal.Types
import qualified Web.Spock.Internal.SessionVault as SV

import Data.Monoid
import Network.HTTP.Types.Status
import qualified Data.Text as T
import qualified Data.Text.Encoding as T

-- | NOP session hooks
defaultSessionHooks :: SessionHooks a
defaultSessionHooks =
    SessionHooks
    { sh_removed = const $ return ()
    }

-- | Session configuration with reasonable defaults and an
-- stm based session store
defaultSessionCfg :: a -> IO (SessionCfg conn a st)
defaultSessionCfg emptySession =
  do store <- SV.newStmSessionStore
     return
       SessionCfg
       { sc_cookieName = "spockcookie"
       , sc_sessionTTL = 3600
       , sc_sessionIdEntropy = 64
       , sc_sessionExpandTTL = True
       , sc_emptySession = emptySession
       , sc_store = store
       , sc_housekeepingInterval = 60 * 10
       , sc_hooks = defaultSessionHooks
       }

-- | Spock configuration with reasonable defaults such as a basic error page
-- and 5MB request body limit
defaultSpockCfg :: sess -> PoolOrConn conn -> st -> IO (SpockCfg conn sess st)
defaultSpockCfg sess conn st =
  do defSess <- defaultSessionCfg sess
     return
       SpockCfg
       { spc_initialState = st
       , spc_database = conn
       , spc_sessionCfg = defSess
       , spc_maxRequestSize = Just (5 * 1024 * 1024)
       , spc_errorHandler = errorHandler
       }

errorHandler :: Status -> ActionCtxT () IO ()
errorHandler status = html $ errorTemplate status

-- Danger! This should better be done using combinators, but we do not
-- want Spock depending on a specific html combinator framework
errorTemplate :: Status -> T.Text
errorTemplate s =
    "<html><head>"
    <> "<title>" <> message <> "</title>"
    <> "</head>"
    <> "<body>"
    <> "<h1>" <> message <> "</h1>"
    <> "<a href='https://www.spock.li'>powered by Spock</a>"
    <> "</body>"
    where
      message =
          showT (statusCode s) <> " - " <> T.decodeUtf8 (statusMessage s)
      showT = T.pack . show