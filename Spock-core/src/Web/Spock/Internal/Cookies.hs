{-# LANGUAGE OverloadedStrings #-}
module Web.Spock.Internal.Cookies where

import Data.Time
import qualified Data.ByteString as BS
import qualified Data.ByteString.Builder as B
import qualified Data.ByteString.Lazy as BSL
import qualified Data.Text as T
import qualified Data.Text.Encoding as T
import qualified Web.Cookie as C
import qualified Network.HTTP.Types.URI as URI (urlEncode, urlDecode)

-- | Cookie settings
data CookieSettings
    = CookieSettings
    { cs_EOL :: CookieEOL
        -- ^ cookie expiration setting, see 'CookieEOL'
    , cs_path :: Maybe BS.ByteString
        -- ^ a path for the cookie
    , cs_domain :: Maybe BS.ByteString
        -- ^ a domain for the cookie. 'Nothing' means no domain is set
    , cs_HTTPOnly :: Bool
        -- ^ whether the cookie should be set as HttpOnly
    , cs_secure :: Bool
        -- ^ whether the cookie should be marked secure (sent over HTTPS only)
    }

-- | Setting cookie expiration
data CookieEOL
    = CookieValidUntil UTCTime
    -- ^ a point in time in UTC until the cookie is valid
    | CookieValidFor NominalDiffTime
    -- ^ a period (in seconds) for which the cookie is valid
    | CookieValidForSession
    -- ^ the cookie expires with the browser session
    | CookieValidForever
    -- ^ the cookie will have an expiration date in the far future

-- | Default cookie settings, equals
--
-- > CookieSettings
-- >   { cs_EOL      = CookieValidForSession
-- >   , cs_HTTPOnly = False
-- >   , cs_secure   = False
-- >   , cs_domain   = Nothing
-- >   , cs_path     = Just "/"
-- >   }
--
defaultCookieSettings :: CookieSettings
defaultCookieSettings =
    CookieSettings
    { cs_EOL = CookieValidForSession
    , cs_HTTPOnly = False
    , cs_secure = False
    , cs_domain = Nothing
    , cs_path = Just "/"
    }

parseCookies :: BS.ByteString -> [(T.Text, T.Text)]
parseCookies =
    map (\(a, b) -> (T.decodeUtf8 a, T.decodeUtf8 $ URI.urlDecode True b)) .
    C.parseCookies

generateCookieHeaderString ::
    T.Text
    -> T.Text
    -> CookieSettings
    -> UTCTime
    -> BS.ByteString
generateCookieHeaderString name value cs now =
     let farFuture =
             -- don't forget to bump this ...
             UTCTime (fromGregorian 2030 1 1) 0
         (expire, maxAge) =
             case cs_EOL cs of
                 CookieValidUntil t ->
                     (Just t, Just (t `diffUTCTime` now))
                 CookieValidFor x ->
                     (Just (x `addUTCTime` now), Just x)
                 CookieValidForSession ->
                     (Nothing, Nothing)
                 CookieValidForever ->
                     (Just farFuture, Just (farFuture `diffUTCTime` now))
         adjustMaxAge t =
             if t < 0 then 0 else t
         cookieVal =
             C.def
             { C.setCookieName = T.encodeUtf8 name
             , C.setCookieValue = URI.urlEncode True $ T.encodeUtf8 value
             , C.setCookiePath = cs_path cs
             , C.setCookieExpires = expire
             , C.setCookieMaxAge = (fromRational . adjustMaxAge . toRational) <$> maxAge
             , C.setCookieDomain = cs_domain cs
             , C.setCookieHttpOnly = cs_HTTPOnly cs
             , C.setCookieSecure = cs_secure cs
             }
     in renderCookie cookieVal

renderCookie :: C.SetCookie -> BS.ByteString
renderCookie = BSL.toStrict . B.toLazyByteString . C.renderSetCookie
