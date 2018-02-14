#include "echograph.h"
#include "commons.h"
#include <QSettings>
#include <QApplication>
#include "echoplot.h"
#include "ui_echograph.h"
#include "moc_echograph.cpp"

#define NSMAX2 1366

EchoGraph::EchoGraph(QSettings * settings, QWidget *parent) :
  QDialog {parent, Qt::Window | Qt::WindowTitleHint | Qt::WindowCloseButtonHint | Qt::WindowMinimizeButtonHint},
  m_settings (settings),
  ui(new Ui::EchoGraph)
{
  ui->setupUi(this);
  setWindowTitle (QApplication::applicationName () + " - " + tr ("Echo Graph"));
  installEventFilter(parent);                   //Installing the filter
  ui->echoPlot->setCursor(Qt::CrossCursor);
  setMaximumWidth(480);
  setMaximumHeight(320);
  ui->echoPlot->setMaximumHeight(280);

//Restore user's settings
  m_settings->beginGroup("EchoGraph");
  restoreGeometry (m_settings->value ("geometry", saveGeometry ()).toByteArray ());
  ui->echoPlot->setPlotZero(m_settings->value("PlotZero", 0).toInt());
  ui->echoPlot->setPlotGain(m_settings->value("PlotGain", 0).toInt());
  ui->zeroSlider->setValue(ui->echoPlot->getPlotZero());
  ui->gainSlider->setValue(ui->echoPlot->getPlotGain());
  int n=m_settings->value("Smooth",0).toInt();
  ui->echoPlot->m_smooth=n;
  ui->smoothSpinBox->setValue(n);
  //n=m_settings->value("EchoBPP",1).toInt();
  n = 2;    //for Raspberry pi Fixed Sized
  ui->echoPlot->m_binsPerPixel=n;
  ui->binsPerPixelSpinBox->setValue(n);
  ui->echoPlot->m_blue=m_settings->value("BlueCurve",false).toBool();
  m_nColor=m_settings->value("EchoColors",0).toInt();
  m_settings->endGroup();
  ui->echoPlot->setColors(m_nColor);

}

EchoGraph::~EchoGraph()
{
  saveSettings();
}

void EchoGraph::closeEvent (QCloseEvent * e)
{
  saveSettings ();
  QDialog::closeEvent (e);
}

void EchoGraph::saveSettings()
{
//Save user's settings
  m_settings->beginGroup("EchoGraph");
  m_settings->setValue ("geometry", saveGeometry ());
  m_settings->setValue("PlotZero",ui->echoPlot->m_plotZero);
  m_settings->setValue("PlotGain",ui->echoPlot->m_plotGain);
  m_settings->setValue("Smooth",ui->echoPlot->m_smooth);
  m_settings->setValue("EchoBPP",ui->echoPlot->m_binsPerPixel);
  m_settings->setValue("BlueCurve",ui->echoPlot->m_blue);
  m_settings->setValue("EchoColors",m_nColor);
  m_settings->endGroup();
}

void EchoGraph::plotSpec()
{
  ui->echoPlot->draw();
  ui->nsum_label->setText("N: " + QString::number(echocom_.nsum));
}

void EchoGraph::on_smoothSpinBox_valueChanged(int n)
{
  ui->echoPlot->setSmooth(n);
  ui->echoPlot->draw();
}

void EchoGraph::on_gainSlider_valueChanged(int value)
{
  ui->echoPlot->setPlotGain(value);
  ui->echoPlot->draw();
}

void EchoGraph::on_zeroSlider_valueChanged(int value)
{
  ui->echoPlot->setPlotZero(value);
  ui->echoPlot->draw();
}

void EchoGraph::on_binsPerPixelSpinBox_valueChanged(int n)
{
  ui->echoPlot->m_binsPerPixel=n;
  ui->echoPlot->DrawOverlay();
  ui->echoPlot->draw();
}

void EchoGraph::on_pbColors_clicked()
{
  m_nColor = (m_nColor+1) % 6;
  ui->echoPlot->setColors(m_nColor);
}
