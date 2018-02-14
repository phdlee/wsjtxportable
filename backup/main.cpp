#include <iostream>
#include <exception>
#include <stdexcept>
#include <string>

#include <locale.h>
#include <fftw3.h>

#include <QDateTime>
#include <QApplication>
#include <QRegularExpression>
#include <QObject>
#include <QSettings>
#include <QLibraryInfo>
#include <QSysInfo>
#include <QDir>
#include <QStandardPaths>
#include <QStringList>
#include <QLockFile>
#include <QStack>
#include <QSplashScreen>

#if QT_VERSION >= 0x050200
#include <QCommandLineParser>
#include <QCommandLineOption>
#endif

#include "revision_utils.hpp"
#include "MetaDataRegistry.hpp"
#include "SettingsGroup.hpp"
#include "TraceFile.hpp"
#include "MultiSettings.hpp"
#include "mainwindow.h"
#include "commons.h"
#include "lib/init_random_seed.h"
#include "Radio.hpp"
#include "FrequencyList.hpp"
#include "SplashScreen.hpp"
#include "MessageBox.hpp"       // last to avoid nasty MS macro definitions

extern "C" {
  // Fortran procedures we need
  void four2a_(_Complex float *, int * nfft, int * ndim, int * isign, int * iform, int len);
}

namespace
{
  struct RNGSetup
  {
    RNGSetup ()
    {
      // one time seed of pseudo RNGs from current time
      auto seed = QDateTime::currentMSecsSinceEpoch ();
      qsrand (seed);            // this is good for rand() as well
    }
  } seeding;

  class MessageTimestamper
  {
  public:
    MessageTimestamper ()
    {
      prior_handlers_.push (qInstallMessageHandler (message_handler));
    }
    ~MessageTimestamper ()
    {
      if (prior_handlers_.size ()) qInstallMessageHandler (prior_handlers_.pop ());
    }

  private:
    static void message_handler (QtMsgType type, QMessageLogContext const& context, QString const& msg)
    {
      QtMessageHandler handler {prior_handlers_.top ()};
      if (handler)
        {
          handler (type, context,
                   QDateTime::currentDateTimeUtc ().toString ("yy-MM-ddTHH:mm:ss.zzzZ: ") + msg);
        }
    }
    static QStack<QtMessageHandler> prior_handlers_;
  };
  QStack<QtMessageHandler> MessageTimestamper::prior_handlers_;
}

int main(int argc, char *argv[])
{
  // Add timestamps to all debug messages
  MessageTimestamper message_timestamper;

  init_random_seed ();

  // make the Qt type magic happen
  Radio::register_types ();
  register_types ();

  // Multiple instances communicate with jt9 via this
  QSharedMemory mem_jt9;

  QApplication a(argc, argv);
  try
    {
      setlocale (LC_NUMERIC, "C"); // ensure number forms are in
                                   // consistent format, do this after
                                   // instantiating QApplication so
                                   // that GUI has correct l18n

      // Override programs executable basename as application name.
      a.setApplicationName ("WSJT-X");
      a.setApplicationVersion (version ());

#if QT_VERSION >= 0x050200
      QCommandLineParser parser;
      parser.setApplicationDescription ("\n" PROJECT_SUMMARY_DESCRIPTION);
      auto help_option = parser.addHelpOption ();
      auto version_option = parser.addVersionOption ();

      // support for multiple instances running from a single installation
      QCommandLineOption rig_option (QStringList {} << "r" << "rig-name"
                                     , a.translate ("main", "Where <rig-name> is for multi-instance support.")
                                     , a.translate ("main", "rig-name"));
      parser.addOption (rig_option);

      // support for start up configuration
      QCommandLineOption cfg_option (QStringList {} << "c" << "config"
                                     , a.translate ("main", "Where <configuration> is an existing one.")
                                     , a.translate ("main", "configuration"));
      parser.addOption (cfg_option);

      QCommandLineOption test_option (QStringList {} << "test-mode"
                                      , a.translate ("main", "Writable files in test location.  Use with caution, for testing only."));
      parser.addOption (test_option);

      if (!parser.parse (a.arguments ()))
        {
          MessageBox::critical_message (nullptr, a.translate ("main", "Command line error"), parser.errorText ());
          return -1;
        }
      else
        {
          if (parser.isSet (help_option))
            {
              MessageBox::information_message (nullptr, a.translate ("main", "Command line help"), parser.helpText ());
              return 0;
            }
          else if (parser.isSet (version_option))
            {
              MessageBox::information_message (nullptr, a.translate ("main", "Application version"), a.applicationVersion ());
              return 0;
            }
        }

      QStandardPaths::setTestModeEnabled (parser.isSet (test_option));

      // support for multiple instances running from a single installation
      bool multiple {false};
      if (parser.isSet (rig_option) || parser.isSet (test_option))
        {
          auto temp_name = parser.value (rig_option);
          if (!temp_name.isEmpty ())
            {
              if (temp_name.contains (QRegularExpression {R"([\\/,])"}))
                {
                  std::cerr << QObject::tr ("Invalid rig name - \\ & / not allowed").toLocal8Bit ().data () << std::endl;
                  parser.showHelp (-1);
                }
                
              a.setApplicationName (a.applicationName () + " - " + temp_name);
            }

          if (parser.isSet (test_option))
            {
              a.setApplicationName (a.applicationName () + " - test");
            }

          multiple = true;
        }

      // now we have the application name we can open the settings
      MultiSettings multi_settings {parser.value (cfg_option)};

      // find the temporary files path
      QDir temp_dir {QStandardPaths::writableLocation (QStandardPaths::TempLocation)};
      Q_ASSERT (temp_dir.exists ()); // sanity check

      // disallow multiple instances with same instance key
      QLockFile instance_lock {temp_dir.absoluteFilePath (a.applicationName () + ".lock")};
      instance_lock.setStaleLockTime (0);
      bool lock_ok {false};
      while (!(lock_ok = instance_lock.tryLock ()))
        {
          if (QLockFile::LockFailedError == instance_lock.error ())
            {
              auto button = MessageBox::query_message (nullptr
                                                       , a.translate ("main", "Another instance may be running")
                                                       , a.translate ("main", "try to remove stale lock file?")
                                                       , QString {}
                                                       , MessageBox::Yes | MessageBox::Retry | MessageBox::No
                                                       , MessageBox::Yes);
              switch (button)
                {
                case MessageBox::Yes:
                  instance_lock.removeStaleLockFile ();
                  break;

                case MessageBox::Retry:
                  break;

                default:
                  throw std::runtime_error {"Multiple instances must have unique rig names"};
                }
            }
        }
#endif

#if WSJT_QDEBUG_TO_FILE
      // Open a trace file
      TraceFile trace_file {temp_dir.absoluteFilePath (a.applicationName () + "_trace.log")};
      qDebug () << program_title (revision ()) + " - Program startup";
#endif

      // Create a unique writeable temporary directory in a suitable location
      bool temp_ok {false};
      QString unique_directory {QApplication::applicationName ()};
      do
        {
          if (!temp_dir.mkpath (unique_directory)
              || !temp_dir.cd (unique_directory))
            {
              MessageBox::critical_message (nullptr,
                                            a.translate ("main", "Failed to create a temporary directory"),
                                            a.translate ("main", "Path: \"%1\"").arg (temp_dir.absolutePath ()));
              throw std::runtime_error {"Failed to create a temporary directory"};
            }
          if (!temp_dir.isReadable () || !(temp_ok = QTemporaryFile {temp_dir.absoluteFilePath ("test")}.open ()))
            {
              auto button =  MessageBox::critical_message (nullptr,
                                                           a.translate ("main", "Failed to create a usable temporary directory"),
                                                           a.translate ("main", "Another application may be locking the directory"),
                                                           a.translate ("main", "Path: \"%1\"").arg (temp_dir.absolutePath ()),
                                                           MessageBox::Retry | MessageBox::Cancel);
              if (MessageBox::Cancel == button)
                {
                  throw std::runtime_error {"Failed to create a usable temporary directory"};
                }
              temp_dir.cdUp ();  // revert to parent as this one is no good
            }
        }
      while (!temp_ok);

      SplashScreen splash;
      {
        // change this key if you want to force a new splash screen
        // for a new version, the user will be able to re-disable it
        // if they wish
        QString splash_flag_name {"Splash_v1.7"};
        if (multi_settings.common_value (splash_flag_name, true).toBool ())
          {
            QObject::connect (&splash, &SplashScreen::disabled, [&, splash_flag_name] {
                multi_settings.set_common_value (splash_flag_name, false);
                splash.close ();
              });
            splash.show ();
            a.processEvents ();
          }
      }

      int result;
      do
        {
#if WSJT_QDEBUG_TO_FILE
          // announce to trace file and dump settings
          qDebug () << "++++++++++++++++++++++++++++ Settings ++++++++++++++++++++++++++++";
          for (auto const& key: multi_settings.settings ()->allKeys ())
            {
              auto const& value = multi_settings.settings ()->value (key);
              if (value.canConvert<QVariantList> ())
                {
                  auto const sequence = value.value<QSequentialIterable> ();
                  qDebug ().nospace () << key << ": ";
                  for (auto const& item: sequence)
                    {
                      qDebug ().nospace () << '\t' << item;
                    }
                }
              else
                {
                  qDebug ().nospace () << key << ": " << value;
                }
            }
          qDebug () << "---------------------------- Settings ----------------------------";
#endif

          // Create and initialize shared memory segment
          // Multiple instances: use rig_name as shared memory key
          mem_jt9.setKey(a.applicationName ());

          if(!mem_jt9.attach()) {
            if (!mem_jt9.create(sizeof(struct dec_data))) {
              splash.hide ();
              MessageBox::critical_message (nullptr, a.translate ("main", "Shared memory error"),
                                            a.translate ("main", "Unable to create shared memory segment"));
              throw std::runtime_error {"Shared memory error"};
            }
          }
          memset(mem_jt9.data(),0,sizeof(struct dec_data)); //Zero all decoding params in shared memory

          unsigned downSampleFactor;
          {
            SettingsGroup {multi_settings.settings (), "Tune"};

            // deal with Windows Vista and earlier input audio rate
            // converter problems
            downSampleFactor = multi_settings.settings ()->value ("Audio/DisableInputResampling",
#if defined (Q_OS_WIN)
                                                                  // default to true for
                                                                  // Windows Vista and older
                                                                  QSysInfo::WV_VISTA >= QSysInfo::WindowsVersion ? true : false
#else
                                                                  false
#endif
                                                                  ).toBool () ? 1u : 4u;
          }

          // run the application UI
          MainWindow w(temp_dir, multiple, &multi_settings, &mem_jt9, downSampleFactor, &splash);
          w.show();
          splash.raise ();
          QObject::connect (&a, SIGNAL (lastWindowClosed()), &a, SLOT (quit()));
          result = a.exec();
        }
      while (!result && !multi_settings.exit ());

      // clean up lazily initialized resources
      {
        int nfft {-1};
        int ndim {1};
        int isign {1};
        int iform {1};
        // free FFT plan resources
        four2a_ (nullptr, &nfft, &ndim, &isign, &iform, 0);
      }
      fftwf_forget_wisdom ();
      fftwf_cleanup ();

      temp_dir.removeRecursively (); // clean up temp files

      return result;
    }
  catch (std::exception const& e)
    {
      MessageBox::critical_message (nullptr, a.translate ("main", "Fatal error"), e.what ());
      std::cerr << "Error: " << e.what () << '\n';
    }
  catch (...)
    {
      MessageBox::critical_message (nullptr, a.translate ("main", "Unexpected fatal error"));
      std::cerr << "Unexpected fatal error\n";
      throw;			// hoping the runtime might tell us more about the exception
    }
  return -1;
}
