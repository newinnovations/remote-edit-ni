Serializable = require 'serializable'
async = require 'async'
{Emitter} = require 'atom'
hash = require 'string-hash'
_ = require 'underscore-plus'
osenv = require 'osenv'
fs = require 'fs-plus'
ReadWriteLock = require('rwlock');


module.exports =
  class Host
    Serializable.includeInto(this)
    atom.deserializers.add(this)

    constructor: (@alias = null, @hostname, @directory = "/", @username = osenv.user(), @port, @localFiles = [], @usePassword, @lastOpenDirectory) ->
      @emitter = new Emitter
      @searchKey = @hostname
      @configLock = new ReadWriteLock
      atom.config.observe 'remote-edit2.filterHostsUsing', (settings) =>
        @searchKey = @getSearchKey(settings) ? @searchKey

      if atom.config.get 'remote-edit2.clearFileList'
        _.each(@localFiles, (val) =>
          @removeLocalFile(val)
          )
      else
        # Remove localFiles if the underlying file has been deleted on localhost
        _.each(@localFiles, (val) =>
          fs.exists(val.path, (exists) =>
            @removeLocalFile(val) if not exists
            )
          )

    getSearchKey: (searchKeySettings) ->
      toReturn = ""
      toReturn = "#{toReturn} #{@alias}" if searchKeySettings["alias"]
      toReturn = "#{toReturn} #{@hostname}" if searchKeySettings["hostname"]
      toReturn = "#{toReturn} #{@username}" if searchKeySettings["username"]
      toReturn = "#{toReturn} #{@port}" if searchKeySettings["port"]
      return toReturn

    getServiceAccount: ->
      "#{@username}@#{@hostname}:#{@port}"

    destroy: ->
      @emitter.dispose()

    getConnectionString: ->
      throw new Error("Function getConnectionString() needs to be implemented by subclasses!")

    connect: (callback, connectionOptions = {}) ->
      throw new Error("Function connect(callback) needs to be implemented by subclasses!")

    close: (callback) ->
      throw new Error("Needs to be implemented by subclasses!")

    getFilesMetadata: (path, callback) ->
      throw new Error("Function getFiles(Callback) needs to be implemented by subclasses!")

    getFile: (localFile, callback) ->
      throw new Error("Must be implemented in subclass!")

    writeFile: (localFile, callback) ->
      throw new Error("Must be implemented in subclass!")

    createFolder: (folderpath, callback) ->
      throw new Error("Must be implemented in subclass!")

    createFile: (filepath, callback) ->
      throw new Error("Must be implemented in subclass!")

    deleteFolderFile: (deletepath, isFolder, callback) ->
      throw new Error("Must be implemented in subclass!")

    renameFolderFile: (path, oldName, newName, isFolder, callback) ->
      throw new Error("Must be implemented in subclass!")

    moveFolderFile: (oldPath, newPath, isFolder, callback) ->
      throw new Error("Must be implemented in subclass!")

    setPermissions: (path, permissions, callback) ->
      throw new Error("Must be implemented in subclass!")

    serializeParams: ->
      throw new Error("Must be implemented in subclass!")

    isConnected: ->
      throw new Error("Must be implemented in subclass!")

    hashCode: ->
      hash(@hostname + @directory + @username + @port)

    addLocalFile: (localFile) ->
      that = @
      @configLock.writeLock((release) ->
        that.localFiles.push(localFile)
        that.emitter.emit 'did-change', localFile
        release()
      )


    removeLocalFile: (localFile) ->
      that = @
      @configLock.writeLock((release) ->
        that.localFiles = _.reject(@localFiles, ((val) -> val == localFile))
        that.emitter.emit 'did-change', localFile
        release()
      )


    delete: ->
      for file in @localFiles
        file.delete()
      @emitter.emit 'did-delete', this

    invalidate: ->
      @emitter.emit 'did-change'

    onDidChange: (callback) ->
      @emitter.on 'did-change', callback

    onDidDelete: (callback) ->
      @emitter.on 'did-delete', callback

    onInfo: (callback) ->
      @emitter.on 'info', callback
