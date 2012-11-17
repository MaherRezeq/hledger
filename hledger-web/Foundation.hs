{-

Define the web application's foundation, in the usual Yesod style.
See a default Yesod app's comments for more details of each part.

-}
module Foundation where

import Prelude
import Yesod
import Yesod.Static
import Yesod.Default.Config
#ifndef DEVELOPMENT
import Yesod.Default.Util (addStaticContentExternal)
#endif
import Network.HTTP.Conduit (Manager)
-- import qualified Settings
import Settings.Development (development)
import Settings.StaticFiles
import Settings ({-widgetFile,-} Extra (..), staticDir)
#ifndef DEVELOPMENT
import Text.Jasmine (minifym)
#endif
import Web.ClientSession (getKey)
-- import Text.Hamlet (hamletFile)

import Hledger.Web.Options
-- import Hledger.Web.Settings
-- import Hledger.Web.Settings.StaticFiles


-- | The site argument for your application. This can be a good place to
-- keep settings and values requiring initialization before your application
-- starts running, such as database connections. Every handler will have
-- access to the data present here.
data App = App
    { settings :: AppConfig DefaultEnv Extra
    , getStatic :: Static -- ^ Settings for static file serving.
    , httpManager :: Manager
      --
    , appOpts    :: WebOpts
    }

-- Set up i18n messages. See the message folder.
mkMessage "App" "messages" "en"

-- This is where we define all of the routes in our application. For a full
-- explanation of the syntax, please see:
-- http://www.yesodweb.com/book/handler
--
-- This function does three things:
--
-- * Creates the route datatype AppRoute. Every valid URL in your
--   application can be represented as a value of this type.
-- * Creates the associated type:
--       type instance Route App = AppRoute
-- * Creates the value resourcesApp which contains information on the
--   resources declared below. This is used in Handler.hs by the call to
--   mkYesodDispatch
--
-- What this function does *not* do is create a YesodSite instance for
-- App. Creating that instance requires all of the handler functions
-- for our application to be in scope. However, the handler functions
-- usually require access to the AppRoute datatype. Therefore, we
-- split these actions into two functions and place them in separate files.
mkYesodData "App" $(parseRoutesFile "config/routes")

-- | A convenience alias.
type AppRoute = Route App

type Form x = Html -> MForm App App (FormResult x, Widget)

-- Please see the documentation for the Yesod typeclass. There are a number
-- of settings which can be configured by overriding methods here.
instance Yesod App where
    approot = ApprootMaster $ appRoot . settings

    -- Store session data on the client in encrypted cookies,
    -- default session idle timeout is 120 minutes
    makeSessionBackend _ = do
        key <- getKey "config/client_session_key.aes"
        return . Just $ clientSessionBackend key 120

    -- defaultLayout widget = do
    --     master <- getYesod
    --     mmsg <- getMessage

    --     -- We break up the default layout into two components:
    --     -- default-layout is the contents of the body tag, and
    --     -- default-layout-wrapper is the entire page. Since the final
    --     -- value passed to hamletToRepHtml cannot be a widget, this allows
    --     -- you to use normal widget features in default-layout.

    --     pc <- widgetToPageContent $ do
    --         $(widgetFile "normalize")
    --         addStylesheet $ StaticR css_bootstrap_css
    --         $(widgetFile "default-layout")
    --     hamletToRepHtml $(hamletFile "templates/default-layout-wrapper.hamlet")

    defaultLayout widget = do 
        pc <- widgetToPageContent $ do
          widget
        hamletToRepHtml [hamlet|
$doctype 5
<html>
 <head>
  <title>#{pageTitle pc}
  ^{pageHead pc}
  <meta http-equiv=Content-Type content="text/html; charset=utf-8">
  <script type=text/javascript src=@{StaticR jquery_js}>
  <script type=text/javascript src=@{StaticR jquery_url_js}>
  <script type=text/javascript src=@{StaticR jquery_flot_js}>
  <!--[if lte IE 8]><script language="javascript" type="text/javascript" src="excanvas.min.js"></script><![endif]-->
  <script type=text/javascript src=@{StaticR dhtmlxcommon_js}>
  <script type=text/javascript src=@{StaticR dhtmlxcombo_js}>
  <script type=text/javascript src=@{StaticR hledger_js}>
  <link rel=stylesheet type=text/css media=all href=@{StaticR style_css}>
 <body>
  ^{pageBody pc}
|]

    -- -- This is done to provide an optimization for serving static files from
    -- -- a separate domain. Please see the staticRoot setting in Settings.hs
    -- urlRenderOverride y (StaticR s) =
    --     Just $ uncurry (joinPath y (Settings.staticRoot $ settings y)) $ renderRoute s
    -- urlRenderOverride _ _ = Nothing

#ifndef DEVELOPMENT
    -- This function creates static content files in the static folder
    -- and names them based on a hash of their content. This allows
    -- expiration dates to be set far in the future without worry of
    -- users receiving stale content.
    addStaticContent = addStaticContentExternal minifym base64md5 Settings.staticDir (StaticR . flip StaticRoute [])
#endif

    -- Place Javascript at bottom of the body tag so the rest of the page loads first
    jsLoader _ = BottomOfBody

    -- What messages should be logged. The following includes all messages when
    -- in development, and warnings and errors in production.
    shouldLog _ _source level =
        development || level == LevelWarn || level == LevelError

-- This instance is required to use forms. You can modify renderMessage to
-- achieve customized and internationalized form validation messages.
instance RenderMessage App FormMessage where
    renderMessage _ _ = defaultFormMessage

-- | Get the 'Extra' value, used to hold data from the settings.yml file.
getExtra :: Handler Extra
getExtra = fmap (appExtra . settings) getYesod

-- Note: previous versions of the scaffolding included a deliver function to
-- send emails. Unfortunately, there are too many different options for us to
-- give a reasonable default. Instead, the information is available on the
-- wiki:
--
-- https://github.com/yesodweb/yesod/wiki/Sending-email