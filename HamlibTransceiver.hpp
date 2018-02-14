#ifndef HAMLIB_TRANSCEIVER_HPP_
#define HAMLIB_TRANSCEIVER_HPP_

#include <tuple>

#include <QString>

#include <hamlib/rig.h>

#include "TransceiverFactory.hpp"
#include "PollingTransceiver.hpp"

extern "C"
{
  typedef struct rig RIG;
  struct rig_caps;
  typedef int vfo_t;
}

// hamlib transceiver and PTT mostly delegated directly to hamlib Rig class
class HamlibTransceiver final
  : public PollingTransceiver
{
  Q_OBJECT;                     // for translation context

 public:
  static void register_transceivers (TransceiverFactory::Transceivers *);
  static void unregister_transceivers ();

  explicit HamlibTransceiver (int model_number, TransceiverFactory::ParameterPack const&,
                              QObject * parent = nullptr);
  explicit HamlibTransceiver (TransceiverFactory::PTTMethod ptt_type, QString const& ptt_port,
                              QObject * parent = nullptr);

 private:
  int do_start () override;
  void do_stop () override;
  void do_frequency (Frequency, MODE, bool no_ignore) override;
  void do_tx_frequency (Frequency, MODE, bool no_ignore) override;
  void do_mode (MODE) override;
  void do_ptt (bool) override;

  void poll () override;

  void error_check (int ret_code, QString const& doing) const;
  void set_conf (char const * item, char const * value);
  QByteArray get_conf (char const * item);
  Transceiver::MODE map_mode (rmode_t) const;
  rmode_t map_mode (Transceiver::MODE mode) const;
  std::tuple<vfo_t, vfo_t> get_vfos (bool for_split) const;

  struct RIGDeleter {static void cleanup (RIG *);};
  QScopedPointer<RIG, RIGDeleter> rig_;

  bool back_ptt_port_;
  bool one_VFO_;
  bool is_dummy_;

  // these are saved on destruction so we can start new instances
  // where the last one left off
  static freq_t dummy_frequency_;
  static rmode_t dummy_mode_;

  bool mutable reversed_;

  bool freq_query_works_;
  bool mode_query_works_;
  bool split_query_works_;
  bool tickle_hamlib_;          // Hamlib requires a
                                // rig_set_split_vfo() call to
                                // establish the Tx VFO
  bool get_vfo_works_;          // Net rigctl promises what it can't deliver
  bool set_vfo_works_;          // More rigctl promises which it can't deliver
};

#endif
