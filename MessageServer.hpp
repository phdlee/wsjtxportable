#ifndef MESSAGE_SERVER_HPP__
#define MESSAGE_SERVER_HPP__

#include <QObject>
#include <QTime>
#include <QDateTime>
#include <QHostAddress>

#include "udp_export.h"
#include "Radio.hpp"

#include "pimpl_h.hpp"

class QString;

//
// MessageServer - a reference implementation of a message server
//                  matching the MessageClient class at the other end
//                  of the wire
//
// This class is fully functioning and suitable for use in C++
// applications that use the Qt framework. Other applications should
// use this classes' implementation as a reference implementation.
//
class UDP_EXPORT MessageServer
  : public QObject
{
  Q_OBJECT;

public:
  using port_type = quint16;
  using Frequency = Radio::Frequency;

  MessageServer (QObject * parent = nullptr,
                 QString const& version = QString {}, QString const& revision = QString {});

  // start or restart the server, if the multicast_group_address
  // argument is given it is assumed to be a multicast group address
  // which the server will join
  Q_SLOT void start (port_type port,
                     QHostAddress const& multicast_group_address = QHostAddress {});

  // ask the client with identification 'id' to make the same action
  // as a double click on the decode would
  //
  // note that the client is not obliged to take any action and only
  // takes any action if the decode is present and is a CQ or QRZ message
  Q_SLOT void reply (QString const& id, QTime time, qint32 snr, float delta_time, quint32 delta_frequency
                     , QString const& mode, QString const& message, bool low_confidence, quint8 modifiers);

  // ask the client with identification 'id' to replay all decodes
  Q_SLOT void replay (QString const& id);

  // ask the client with identification 'id' to halt transmitting
  // auto_only just disables auto Tx, otherwise halt is immediate
  Q_SLOT void halt_tx (QString const& id, bool auto_only);

  // ask the client with identification 'id' to set the free text
  // message and optionally send it ASAP
  Q_SLOT void free_text (QString const& id, QString const& text, bool send);

  // the following signals are emitted when a client broadcasts the
  // matching message
  Q_SIGNAL void client_opened (QString const& id, QString const& version, QString const& revision);
  Q_SIGNAL void status_update (QString const& id, Frequency, QString const& mode, QString const& dx_call
                               , QString const& report, QString const& tx_mode, bool tx_enabled
                               , bool transmitting, bool decoding, qint32 rx_df, qint32 tx_df
                               , QString const& de_call, QString const& de_grid, QString const& dx_grid
                               , bool watchdog_timeout, QString const& sub_mode, bool fast_mode);
  Q_SIGNAL void client_closed (QString const& id);
  Q_SIGNAL void decode (bool is_new, QString const& id, QTime time, qint32 snr, float delta_time
                        , quint32 delta_frequency, QString const& mode, QString const& message
                        , bool low_confidence, bool off_air);
  Q_SIGNAL void WSPR_decode (bool is_new, QString const& id, QTime time, qint32 snr, float delta_time, Frequency
                             , qint32 drift, QString const& callsign, QString const& grid, qint32 power
                             , bool off_air);
  Q_SIGNAL void qso_logged (QString const& id, QDateTime time_off, QString const& dx_call, QString const& dx_grid
                            , Frequency dial_frequency, QString const& mode, QString const& report_sent
                            , QString const& report_received, QString const& tx_power, QString const& comments
                            , QString const& name, QDateTime time_on);
  Q_SIGNAL void clear_decodes (QString const& id);

  // this signal is emitted when a network error occurs
  Q_SIGNAL void error (QString const&) const;

private:
  class UDP_NO_EXPORT impl;
  pimpl<impl> m_;
};

#endif
