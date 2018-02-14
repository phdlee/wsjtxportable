// -*- Mode: C++ -*-
#ifndef SOUNDOUT_H__
#define SOUNDOUT_H__

#include <QObject>
#include <QString>
#include <QAudioOutput>
#include <QAudioDeviceInfo>

class QAudioDeviceInfo;

// An instance of this sends audio data to a specified soundcard.

class SoundOutput
  : public QObject
{
  Q_OBJECT;
  
public:
  SoundOutput ()
    : m_msBuffered {0u}
    , m_volume {1.0}
  {
  }

  qreal attenuation () const;

public Q_SLOTS:
  void setFormat (QAudioDeviceInfo const& device, unsigned channels, unsigned msBuffered = 0u);
  void restart (QIODevice *);
  void suspend ();
  void resume ();
  void reset ();
  void stop ();
  void setAttenuation (qreal);	/* unsigned */
  void resetAttenuation ();	/* to zero */
  
Q_SIGNALS:
  void error (QString message) const;
  void status (QString message) const;

private:
  bool audioError () const;

private Q_SLOTS:
  void handleStateChanged (QAudio::State);

private:
  QScopedPointer<QAudioOutput> m_stream;
  unsigned m_msBuffered;
  qreal m_volume;
};

#endif
