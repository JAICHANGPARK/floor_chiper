package com.davidmartos96.sqflite_sqlcipher;

import android.util.Log;

import net.sqlcipher.database.SQLiteDatabase;
import net.sqlcipher.database.SQLiteDatabaseHook;
import net.sqlcipher.DatabaseErrorHandler;
import java.io.File;

import static com.davidmartos96.sqflite_sqlcipher.Constant.TAG;

class Database {
    final boolean singleInstance;
    final String path;
    final String password;
    final int id;
    final int logLevel;
    SQLiteDatabase sqliteDatabase;
    boolean inTransaction;


    Database(String path, String password, int id, boolean singleInstance, int logLevel) {
        this.path = path;
        this.password = (password != null) ? password : "";

        this.singleInstance = singleInstance;
        this.id = id;
        this.logLevel = logLevel;
    }

    public void open() {
        openWithFlags(SQLiteDatabase.CREATE_IF_NECESSARY);

    }

    // Change default error handler to avoid erasing the existing file.
    public void openReadOnly() {
        openWithFlags(SQLiteDatabase.OPEN_READONLY, new DatabaseErrorHandler() {
            @Override
            public void onCorruption(SQLiteDatabase dbObj) {
                // ignored
                // default implementation delete the file
                //
                // This happens asynchronously so cannot be tracked. However a simple
                // access should fail
            }
        });
    }

    private void openWithFlags(int flags) {
        openWithFlags(flags, null);
    }

    private void openWithFlags(int flags, DatabaseErrorHandler errorHandler) {
        try {
            sqliteDatabase = SQLiteDatabase.openDatabase(path, password, null, flags, null, errorHandler);

        }catch (Exception e) {
            Log.d(TAG, "Opening db in " + path + " with PRAGMA cipher_migrate");
            SQLiteDatabaseHook hook = new SQLiteDatabaseHook() {
                @Override
                public void preKey(net.sqlcipher.database.SQLiteDatabase database) {
                }

                @Override
                public void postKey(net.sqlcipher.database.SQLiteDatabase database) {
                    database.rawExecSQL("PRAGMA cipher_migrate;");
                }
            };

            sqliteDatabase = SQLiteDatabase.openDatabase(path, password, null, flags, hook, errorHandler);
        }
    }

    public void close() {
        sqliteDatabase.close();
    }

    public SQLiteDatabase getWritableDatabase() {
        return sqliteDatabase;
    }

    public SQLiteDatabase getReadableDatabase() {
        return sqliteDatabase;
    }

    public boolean enableWriteAheadLogging() {
        try {
            sqliteDatabase.rawExecSQL("PRAGMA journal_mode=WAL;");
        } catch (Exception e) {
            Log.e(TAG, getThreadLogPrefix() + "enable WAL error: " + e);
            return false;
        }
        return true;
    }

    String getThreadLogTag() {
        Thread thread = Thread.currentThread();

        return "" + id + "," + thread.getName() + "(" + thread.getId() + ")";
    }

    String getThreadLogPrefix() {
        return "[" + getThreadLogTag() + "] ";
    }


    static void deleteDatabase(String path) {
        File file = new File(path);

        file.delete();
        new File(file.getPath() + "-journal").delete();
        new File(file.getPath() + "-shm").delete();
        new File(file.getPath() + "-wal").delete();
    }
}
