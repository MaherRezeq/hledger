{-|

hledger-web - a hledger add-on providing a web interface.
Copyright (c) 2007-2012 Simon Michael <simon@joyful.com>
Released under GPL version 3 or later.

-}

module Hledger.Web.Main
where

-- yesod scaffold imports
import Prelude              (IO)
import Yesod.Default.Config --(fromArgs)
-- import Yesod.Default.Main   (defaultMain)
import Settings            --  (parseExtra)
import Application          (makeApplication)
import Data.Conduit.Network (HostPreference(HostIPv4))
import Network.Wai.Handler.Warp (runSettings, defaultSettings, settingsPort)
import Network.Wai.Handler.Launch (runUrlPort)
--
import Prelude hiding (putStrLn)
import Control.Concurrent (forkIO)
import Control.Monad (when)
import Data.Text (pack)
import System.Exit (exitSuccess)
import System.IO (hFlush, stdout)
import Text.Printf

import Hledger
import Hledger.Utils.UTF8IOCompat (putStrLn)
import Hledger.Cli hiding (progname,prognameandversion)
import Hledger.Web.Options


main :: IO ()
main = do
  opts <- getHledgerWebOpts
  when (debug_ $ cliopts_ opts) $ printf "%s\n" prognameandversion >> printf "opts: %s\n" (show opts)
  runWith opts

runWith :: WebOpts -> IO ()
runWith opts
  | "help" `in_` (rawopts_ $ cliopts_ opts)            = putStr (showModeHelp webmode) >> exitSuccess
  | "version" `in_` (rawopts_ $ cliopts_ opts)         = putStrLn prognameandversion >> exitSuccess
  | "binary-filename" `in_` (rawopts_ $ cliopts_ opts) = putStrLn (binaryfilename progname)
  | otherwise = do
    requireJournalFileExists =<< journalFilePathFromOpts (cliopts_ opts)
    withJournalDo' opts web

withJournalDo' :: WebOpts -> (WebOpts -> Journal -> IO ()) -> IO ()
withJournalDo' opts cmd = do
  journalFilePathFromOpts (cliopts_ opts) >>= readJournalFile Nothing Nothing >>=
    either error' (cmd opts . journalApplyAliases (aliasesFromOpts $ cliopts_ opts))

-- | The web command.
web :: WebOpts -> Journal -> IO ()
web opts j = do
  d <- getCurrentDay
  let j' = filterJournalTransactions (queryFromOpts d $ reportopts_ $ cliopts_ opts) j
      p = port_ opts
      u = base_url_ opts
  _ <- printf "Starting http server on port %d with base url %s\n" p u
  app <- makeApplication j' AppConfig{appEnv = Development
                                    ,appPort = p
                                    ,appRoot = pack u
                                    ,appHost = HostIPv4
                                    ,appExtra = Extra "" Nothing
                                    }
  if False
   then
    runSettings defaultSettings{settingsPort=p} app
   else do
    putStrLn "Launching web browser" >> hFlush stdout
    forkIO $ runUrlPort p "" app
    putStrLn "Press ENTER to quit (or close browser windows for 2 minutes)" >> hFlush stdout
    getLine >> exitSuccess
    
