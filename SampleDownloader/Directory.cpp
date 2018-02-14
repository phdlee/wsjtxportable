#include "Directory.hpp"

#include <QVariant>
#include <QString>
#include <QHeaderView>
#include <QStringList>
#include <QFileInfo>
#include <QDir>
#include <QNetworkAccessManager>
#include <QAuthenticator>
#include <QNetworkReply>
#include <QTreeWidgetItem>
#include <QTreeWidgetItemIterator>
#include <QJsonDocument>
#include <QJsonParseError>
#include <QJsonArray>
#include <QJsonObject>
#include <QRegularExpression>

#include "Configuration.hpp"
#include "DirectoryNode.hpp"
#include "FileNode.hpp"
#include "revision_utils.hpp"
#include "MessageBox.hpp"

#include "moc_Directory.cpp"

namespace
{
  char const * samples_dir_name = "samples";
  QString const contents_file_name = "contents_" + version (false) + ".json";
}

Directory::Directory (Configuration const * configuration
                      , QNetworkAccessManager * network_manager
                      , QWidget * parent)
  : QTreeWidget {parent}
  , configuration_ {configuration}
  , network_manager_ {network_manager}
  , http_only_ {false}
  , root_dir_ {configuration_->save_directory ()}
  , contents_ {this
        , network_manager_
        , QDir {root_dir_.absoluteFilePath (samples_dir_name)}.absoluteFilePath (contents_file_name)}
{
  dir_icon_.addPixmap (style ()->standardPixmap (QStyle::SP_DirClosedIcon), QIcon::Normal, QIcon::Off);
  dir_icon_.addPixmap (style ()->standardPixmap (QStyle::SP_DirOpenIcon), QIcon::Normal, QIcon::On);
  file_icon_.addPixmap (style ()->standardPixmap (QStyle::SP_FileIcon));

  setColumnCount (2);
  setHeaderLabels ({"File", "Progress"});
  header ()->setSectionResizeMode (QHeaderView::ResizeToContents);
  setItemDelegate (&item_delegate_);

  connect (network_manager_, &QNetworkAccessManager::authenticationRequired
           , this, &Directory::authentication);
  connect (this, &Directory::itemChanged, [this] (QTreeWidgetItem * item) {
      switch (item->type ())
        {
        case FileNode::Type:
          {
            FileNode * node = static_cast<FileNode *> (item);
            if (!node->sync (node->checkState (0) == Qt::Checked))
              {
                FileNode::sync_blocker b {node};
                node->setCheckState (0, node->checkState (0) == Qt::Checked ? Qt::Unchecked : Qt::Checked);
              }
          }
          break;

        default:
          break;
        }
    });
}

bool Directory::url_root (QUrl root)
{
  if (!root.path ().endsWith ('/'))
    {
      root.setPath (root.path () + '/');
    }
  bool valid = root.isValid ();
  if (valid)
    {
      url_root_ = root;
    }
  return valid;
}

void Directory::error (QString const& title, QString const& message)
{
  MessageBox::warning_message (this, title, message);
}

bool Directory::refresh (bool http_only)
{
  abort ();
  clear ();
  // update locations
  root_dir_ = configuration_->save_directory ();
  QDir contents_dir {root_dir_.absoluteFilePath (samples_dir_name)};
  contents_.local_file_path (contents_dir.absoluteFilePath (contents_file_name));
  contents_.http_only (http_only_ = http_only);
  QUrl url {url_root_.resolved (QDir {root_dir_.relativeFilePath (samples_dir_name)}.filePath (contents_file_name))};
  if (url.isValid ())
    {
      return contents_.sync (url, true, true); // attempt to fetch contents
    }
  else
    {
      MessageBox::warning_message (this
                                   , tr ("URL Error")
                                   , tr ("Invalid URL:\n\"%1\"")
                                   .arg (url.toDisplayString ()));
    }
  return false;
}

void Directory::download_finished (bool success)
{
  if (success)
    {
      QFile contents {contents_.local_file_path ()};
      if (contents.open (QFile::ReadOnly | QFile::Text))
        {
          QJsonParseError json_status;
          auto content = QJsonDocument::fromJson (contents.readAll (), &json_status);
          if (json_status.error)
            {
              MessageBox::warning_message (this
                                           , tr ("JSON Error")
                                           , tr ("Contents file syntax error %1 at character offset %2")
                                           .arg (json_status.errorString ()).arg (json_status.offset));
              return;
            }
          if (!content.isArray ())
            {
              MessageBox::warning_message (this, tr ("JSON Error")
                                           , tr ("Contents file top level must be a JSON array"));
              return;
            }
          QTreeWidgetItem * parent {invisibleRootItem ()};
          parent = new DirectoryNode {parent, samples_dir_name};
          parent->setIcon (0, dir_icon_);
          parent->setExpanded (true);
          parse_entries (content.array (), root_dir_.relativeFilePath (samples_dir_name), parent);
        }
      else
        {
          MessageBox::warning_message (this, tr ("File System Error")
                                       , tr ("Failed to open \"%1\"\nError: %2 - %3")
                                       .arg (contents.fileName ())
                                       .arg (contents.error ())
                                       .arg (contents.errorString ()));
        }
    }
}

void Directory::parse_entries (QJsonArray const& entries, QDir const& dir, QTreeWidgetItem * parent)
{
  if (dir.isRelative () && !dir.path ().startsWith ('.'))
    {
      for (auto const& value: entries)
        {
          if (value.isObject ())
            {
              auto const& entry = value.toObject ();
              auto const& name = entry["name"].toString ();
              if (name.size () && !name.contains (QRegularExpression {R"([/:;])"}))
                {
                  auto const& type = entry["type"].toString ();
                  if ("file" == type)
                    {
                      QUrl url {url_root_.resolved (dir.filePath (name))};
                      if (url.isValid ())
                        {
                          auto node = new FileNode {parent, network_manager_
                                                    , QDir {root_dir_.filePath (dir.path ())}.absoluteFilePath (name)
                                                    , url, http_only_};
                          FileNode::sync_blocker b {node};
                          node->setIcon (0, file_icon_);
                          node->setCheckState (0, node->local () ? Qt::Checked : Qt::Unchecked);
                          update (parent);
                        }
                      else
                        {
                          MessageBox::warning_message (this
                                                       , tr ("URL Error")
                                                       , tr ("Invalid URL:\n\"%1\"")
                                                       .arg (url.toDisplayString ()));
                        }
                    }
                  else if ("directory" == type)
                    {
                          auto node = new DirectoryNode {parent, name};
                          node->setIcon (0, dir_icon_);
                          auto const& entries = entry["entries"];
                          if (entries.isArray ())
                            {
                              parse_entries (entries.toArray ()
                                             , QDir {root_dir_.relativeFilePath (dir.path ())}.filePath (name)
                                             , node);
                            }
                          else
                            {
                              MessageBox::warning_message (this, tr ("JSON Error")
                                                           , tr ("Contents entries must be a JSON array"));
                            }
                    }
                  else
                    {
                      MessageBox::warning_message (this, tr ("JSON Error")
                                                   , tr ("Contents entries must have a valid type"));
                    }
                }
              else
                {
                  MessageBox::warning_message (this, tr ("JSON Error")
                                               , tr ("Contents entries must have a valid name"));
                }
            }
          else
            {
              MessageBox::warning_message (this, tr ("JSON Error")
                                           , tr ("Contents entries must be JSON objects"));
            }
        }
    }
  else
    {
      MessageBox::warning_message (this, tr ("JSON Error")
                                   , tr ("Contents directories must be relative and within \"%1\"")
                                   .arg (samples_dir_name));
    }
}

void Directory::abort ()
{
  QTreeWidgetItemIterator iter {this};
  while (*iter)
    {
      if ((*iter)->type () == FileNode::Type)
        {
          auto * node = static_cast<FileNode *> (*iter);
          node->abort ();
        }
      ++iter;
    }
}

namespace
{
  //
  // traverse the passed subtree accumulating the number of items, the
  // number we have size data for, the bytes downloaded so far and the
  // maximum bytes to expect
  //
  int recurse_children (QTreeWidgetItem const * item, int * counted
                        , qint64 * bytes, qint64 * max)
  {
    int items {0};
    for (int index {0}; index < item->childCount (); ++index)
      {
        auto const * child = item->child (index);
        if (child->type () == FileNode::Type)  // only count files
          {
            ++items;
            if (auto size = child->data (1, Qt::UserRole).toLongLong ())
              {
                *max += size;
                ++*counted;
              }
            *bytes += child->data (1, Qt::DisplayRole).toLongLong ();
          }
        else
          {
            // recurse into sub-directory subtrees
            items += recurse_children (child, counted, bytes, max);
          }
      }
    return items;
  }
}

void Directory::update (QTreeWidgetItem * item)
{
  // iterate the tree under item and accumulate the progress
  if (item)
    {
      Q_ASSERT (item->type () == DirectoryNode::Type);
      qint64 max {0};
      qint64 bytes {0};
      int counted {0};

      // get the count, progress and size of children
      int items {recurse_children (item, &counted, &bytes, &max)};

      // estimate size of items not yet downloaded as average of
      // those actually present
      if (counted)
        {
          max += (items - counted) * max / counted;
        }

      // save as our progress
      item->setData (1, Qt::UserRole, max);
      item->setData (1, Qt::DisplayRole, bytes);

      // recurse up to top
      update (item->parent ());
    }
}

void Directory::authentication (QNetworkReply * /* reply */
                                , QAuthenticator * /* authenticator */)
{
  MessageBox::warning_message (this, tr ("Network Error"), tr ("Authentication required"));
}
