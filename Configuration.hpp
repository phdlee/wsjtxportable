#ifndef CONFIGURATION_HPP_
#define CONFIGURATION_HPP_

#include <QObject>
#include <QFont>

#include "Radio.hpp"
#include "IARURegions.hpp"
#include "AudioDevice.hpp"
#include "Transceiver.hpp"

#include "pimpl_h.hpp"

class QSettings;
class QWidget;
class QAudioDeviceInfo;
class QString;
class QDir;
class Bands;
class FrequencyList_v2;
class StationList;
class QStringListModel;
class QHostAddress;

//
// Class Configuration
//
//  Encapsulates the control, access  and, persistence of user defined
//  settings for the wsjtx GUI.  Setting values are accessed through a
//  QDialog window containing concept orientated tab windows.
//
// Responsibilities
//
//  Provides management of  the CAT and PTT  rig interfaces, providing
//  control access  via a minimal generic  set of Qt slots  and status
//  updates via Qt signals.  Internally  the rig control capability is
//  farmed out  to a  separate thread  since many  of the  rig control
//  functions are blocking.
//
//  All user  settings required by  the wsjtx GUI are  exposed through
//  query methods.  Settings only become  visible once they  have been
//  accepted by the user which is  done by clicking the "OK" button on
//  the settings dialog.
//
//  The QSettings instance  passed to the constructor is  used to read
//  and write user settings.
//
//  Pointers to three QAbstractItemModel  objects are provided to give
//  access to amateur band  information, user working frequencies and,
//  user operating  band information.  These porovide  consistent data
//  models that can  be used in GUI lists or  tables or simply queried
//  for user defined bands, default operating frequencies and, station
//  descriptions.
//
class Configuration final
  : public QObject
{
  Q_OBJECT
  Q_ENUMS (DataMode Type2MsgGen)

public:
  using MODE = Transceiver::MODE;
  using TransceiverState = Transceiver::TransceiverState;
  using Frequency = Radio::Frequency;
  using port_type = quint16;

  enum DataMode {data_mode_none, data_mode_USB, data_mode_data};
  Q_ENUM (DataMode)
  enum Type2MsgGen {type_2_msg_1_full, type_2_msg_3_full, type_2_msg_5_only};
  Q_ENUM (Type2MsgGen)

  explicit Configuration (QDir const& temp_directory, QSettings * settings,
                          QWidget * parent = nullptr);
  ~Configuration ();

  void select_tab (int);
  int exec ();
  bool is_active () const;

  QDir temp_dir () const;
  QDir doc_dir () const;
  QDir data_dir () const;
  QDir writeable_data_dir () const;

  QAudioDeviceInfo const& audio_input_device () const;
  AudioDevice::Channel audio_input_channel () const;
  QAudioDeviceInfo const& audio_output_device () const;
  AudioDevice::Channel audio_output_channel () const;

  // These query methods should be used after a call to exec() to
  // determine if either the audio input or audio output stream
  // parameters have changed. The respective streams should be
  // re-opened if they return true.
  bool restart_audio_input () const;
  bool restart_audio_output () const;

  QString my_callsign () const;
  QString my_grid () const;
  QFont text_font () const;
  QFont decoded_text_font () const;
  qint32 id_interval () const;
  qint32 ntrials() const;
  qint32 aggressive() const;
  qint32 RxBandwidth() const;
  double degrade() const;
  double txDelay() const;
  bool id_after_73 () const;
  bool tx_QSY_allowed () const;
  bool spot_to_psk_reporter () const;
  bool monitor_off_at_startup () const;
  bool monitor_last_used () const;
  bool log_as_RTTY () const;
  bool report_in_comments () const;
  bool prompt_to_log () const;
  bool insert_blank () const;
  bool DXCC () const;
  bool clear_DX () const;
  bool miles () const;
  bool quick_call () const;
  bool disable_TX_on_73 () const;
  int watchdog () const;
  bool TX_messages () const;
  bool split_mode () const;
  bool enable_VHF_features () const;
  bool decode_at_52s () const;
  bool single_decode () const;
  bool twoPass() const;
  bool x2ToneSpacing() const;
  bool contestMode() const;
  bool realTimeDecode() const;
  bool MyDx() const;
  bool CQMyN() const;
  bool NDxG() const;
  bool NN() const;
  bool EMEonly() const;
  bool post_decodes () const;
  QString udp_server_name () const;
  port_type udp_server_port () const;
  bool accept_udp_requests () const;
  bool udpWindowToFront () const;
  bool udpWindowRestore () const;
  Bands * bands ();
  Bands const * bands () const;
  IARURegions::Region region () const;
  FrequencyList_v2 * frequencies ();
  FrequencyList_v2 const * frequencies () const;
  StationList * stations ();
  StationList const * stations () const;
  QStringListModel * macros ();
  QStringListModel const * macros () const;
  QDir save_directory () const;
  QDir azel_directory () const;
  QString rig_name () const;
  Type2MsgGen type_2_msg_gen () const;
  QColor color_CQ () const;
  QColor color_MyCall () const;
  QColor color_TxMsg () const;
  QColor color_DXCC () const;
  QColor color_NewCall () const;
  bool pwrBandTxMemory () const;
  bool pwrBandTuneMemory () const;

  struct CalibrationParams
  {
    CalibrationParams ()
      : intercept {0.}
      , slope_ppm {0.}
    {
    }

    CalibrationParams (double the_intercept, double the_slope_ppm)
      : intercept {the_intercept}
      , slope_ppm {the_slope_ppm}
    {
    }

    double intercept;           // Hertz
    double slope_ppm;           // Hertz
  };

  // Temporarily enable or disable calibration adjustments.
  void enable_calibration (bool = true);

  // Set the calibration parameters and enable calibration corrections.
  void set_calibration (CalibrationParams);

  // This method queries if a CAT and PTT connection is operational.
  bool is_transceiver_online () const;

  // Start the rig connection, safe and normal to call when rig is
  // already open.
  bool transceiver_online ();

  // check if a real rig is configured
  bool is_dummy_rig () const;

  // Frequency resolution of the rig
  //
  //  0 - 1Hz
  //  1 - 10Hz rounded
  // -1 - 10Hz truncated
  //  2 - 100Hz rounded
  // -2 - 100Hz truncated
  int transceiver_resolution () const;

  // Close down connection to rig.
  void transceiver_offline ();

  // Set transceiver frequency in Hertz.
  Q_SLOT void transceiver_frequency (Frequency);

  // Setting a non zero TX frequency means split operation
  // rationalise_mode means ensure TX uses same mode as RX.
  Q_SLOT void transceiver_tx_frequency (Frequency = 0u);

  // Set transceiver mode.
  //
  // Rationalise means ensure TX uses same mode as RX.
  Q_SLOT void transceiver_mode (MODE);

  // Set/unset PTT.
  //
  // Note that this must be called even if VOX PTT is selected since
  // the "Emulate Split" mode requires PTT information to coordinate
  // frequency changes.
  Q_SLOT void transceiver_ptt (bool = true);

  // Attempt to (re-)synchronise transceiver state.
  //
  // Force signal guarantees either a transceiver_update or a
  // transceiver_failure signal.
  //
  // The enforce_mode_and_split parameter ensures that future
  // transceiver updates have the correct mode and split setting
  // i.e. the transceiver is ready for use.
  Q_SLOT void sync_transceiver (bool force_signal = false, bool enforce_mode_and_split = false);


  //
  // These signals indicate a font has been selected and accepted for
  // the application text and decoded text respectively.
  //
  Q_SIGNAL void text_font_changed (QFont);
  Q_SIGNAL void decoded_text_font_changed (QFont);

  //
  // This signal is emitted when the UDP server changes
  //
  Q_SIGNAL void udp_server_changed (QString const& udp_server);
  Q_SIGNAL void udp_server_port_changed (port_type server_port);


  //
  // These signals are emitted and reflect transceiver state changes
  //

  // signals a change in one of the TransceiverState members
  Q_SIGNAL void transceiver_update (Transceiver::TransceiverState const&) const;

  // Signals a failure of a control rig CAT or PTT connection.
  //
  // A failed rig CAT or PTT connection is fatal and the underlying
  // connections are closed automatically. The connections can be
  // re-established with a call to transceiver_online(true) assuming
  // the fault condition has been rectified or is transient.
  Q_SIGNAL void transceiver_failure (QString const& reason) const;

private:
  class impl;
  pimpl<impl> m_;
};

#if QT_VERSION < 0x050500
Q_DECLARE_METATYPE (Configuration::DataMode);
Q_DECLARE_METATYPE (Configuration::Type2MsgGen);
#endif

#if !defined (QT_NO_DEBUG_STREAM)
ENUM_QDEBUG_OPS_DECL (Configuration, DataMode);
ENUM_QDEBUG_OPS_DECL (Configuration, Type2MsgGen);
#endif

ENUM_QDATASTREAM_OPS_DECL (Configuration, DataMode);
ENUM_QDATASTREAM_OPS_DECL (Configuration, Type2MsgGen);

ENUM_CONVERSION_OPS_DECL (Configuration, DataMode);
ENUM_CONVERSION_OPS_DECL (Configuration, Type2MsgGen);

#endif
