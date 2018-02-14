#include "PollingTransceiver.hpp"

#include <exception>

#include <QObject>
#include <QString>
#include <QTimer>

#include "moc_PollingTransceiver.cpp"

namespace
{
  unsigned const polls_to_stabilize {3};
}

PollingTransceiver::PollingTransceiver (int poll_interval, QObject * parent)
  : TransceiverBase {parent}
  , interval_ {poll_interval * 1000}
  , poll_timer_ {nullptr}
  , retries_ {0}
{
}

void PollingTransceiver::start_timer ()
{
  if (interval_)
    {
      if (!poll_timer_)
        {
          poll_timer_ = new QTimer {this}; // pass ownership to
                                           // QObject which handles
                                           // destruction for us

          connect (poll_timer_, &QTimer::timeout, this,
                   &PollingTransceiver::handle_timeout);
        }
      poll_timer_->start (interval_);
    }
  else
    {
      stop_timer ();
    }
}

void PollingTransceiver::stop_timer ()
{
  if (poll_timer_)
    {
      poll_timer_->stop ();
    }
}

void PollingTransceiver::do_post_start ()
{
  start_timer ();
  if (!next_state_.online ())
    {
      // remember that we are expecting to go online
      next_state_.online (true);
      retries_ = polls_to_stabilize;
    }
}

void PollingTransceiver::do_post_stop ()
{
  // not much point waiting for rig to go offline since we are ceasing
  // polls
  stop_timer ();
}

void PollingTransceiver::do_post_frequency (Frequency f, MODE m)
{
  // take care not to set the expected next mode to unknown since some
  // callers use mode == unknown to signify that they do not know the
  // mode and don't care
  if (next_state_.frequency () != f || (m != UNK && next_state_.mode () != m))
    {
      // update expected state with new frequency and set poll count
      next_state_.frequency (f);
      if (m != UNK)
        {
          next_state_.mode (m);
        }
      retries_ = polls_to_stabilize;
    }
}

void PollingTransceiver::do_post_tx_frequency (Frequency f, MODE)
{
  if (next_state_.tx_frequency () != f)
    {
      // update expected state with new TX frequency and set poll
      // count
      next_state_.tx_frequency (f);
      next_state_.split (f); // setting non-zero TX frequency means split
      retries_ = polls_to_stabilize;
    }
}

void PollingTransceiver::do_post_mode (MODE m)
{
  // we don't ever expect mode to goto to unknown
  if (m != UNK && next_state_.mode () != m)
    {
      // update expected state with new mode and set poll count
      next_state_.mode (m);
      retries_ = polls_to_stabilize;
    }
}

void PollingTransceiver::do_post_ptt (bool p)
{
  if (next_state_.ptt () != p)
    {
      // update expected state with new PTT and set poll count
      next_state_.ptt (p);
      retries_ = polls_to_stabilize;
      //retries_ = 0;             // fast feedback on PTT
    }
}

bool PollingTransceiver::do_pre_update ()
{
  // if we are holding off a change then withhold the signal
  if (retries_ && state () != next_state_)
    {
      return false;
    }
  return true;
}

void PollingTransceiver::do_sync (bool force_signal, bool no_poll)
{
  if (!no_poll) poll ();        // tell sub-classes to update our state

  // Signal new state if it is directly requested or, what we expected
  // or, hasn't become what we expected after polls_to_stabilize
  // polls. Unsolicited changes will be signalled immediately unless
  // they intervene in a expected sequence where they will be delayed.
  if (retries_)
    {
      --retries_;
      if (force_signal || state () == next_state_ || !retries_)
        {
          // our client wants a signal regardless
          // or the expected state has arrived
          // or there are no more retries
          force_signal = true;
        }
    }
  else if (force_signal || state () != last_signalled_state_)
    {
      // here is the normal passive polling path either our client has
      // requested a state update regardless of change or state has
      // changed asynchronously
      force_signal = true;
    }

  if (force_signal)
    {
      // reset everything, record and signal the current state
      retries_ = 0;
      next_state_ = state ();
      last_signalled_state_ = state ();
      update_complete (true);
    }
}

void PollingTransceiver::handle_timeout ()
{
  QString message;

  // we must catch all exceptions here since we are called by Qt and
  // inform our parent of the failure via the offline() message
  try
    {
      do_sync ();
    }
  catch (std::exception const& e)
    {
      message = e.what ();
    }
  catch (...)
    {
      message = tr ("Unexpected rig error");
    }
  if (!message.isEmpty ())
    {
      offline (message);
    }
}
