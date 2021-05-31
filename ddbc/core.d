module ddbc.core;

class SQLException : Exception {
	this(string msg) { super(msg); }
}

interface Connection {
	void close();
	void commit();
	string getCatalog();
	bool isClosed();
	void rollback();
	bool getAutoCommit();
	void setAutoCommit(bool autoCommit);
	// statements
	Statement createStatement();
	PreparedStatement prepareStatement(string query);
}

interface ResultSetMetadata {
	int getColumnCount();
	string getColumnName(int columnIndex);
	string getColumnLabel(int columnIndex);
	int getColumnType(int columnIndex);
	bool isNullable(int columnIndex);
}

interface ResultSet {
	void close();
	bool first();
	bool isFirst();
	bool isLast();
	bool next();

	//Retrieves the number, types and properties of this ResultSet object's columns
	ResultSetMetadata getMetaData();
	//Retrieves the Statement object that produced this ResultSet object.
	Statement getStatement();
	//Retrieves the current row number
	int getRow();
	//Retrieves the fetch size for this ResultSet object.
	int getFetchSize();

	int findColumn(string columnName);
	bool getBoolean(int columnIndex);
	bool getBoolean(string columnName);
	ubyte getUbyte(int columnIndex);
	ubyte getUbyte(string columnName);
	ubyte[] getBytes(int columnIndex);
	ubyte[] getBytes(string columnName);
	byte getByte(int columnIndex);
	byte getByte(string columnName);
	short getShort(int columnIndex);
	short getShort(string columnName);
	ushort getUshort(int columnIndex);
	ushort getUshort(string columnName);
	int getInt(int columnIndex);
	int getInt(string columnName);
	uint getUint(int columnIndex);
	uint getUint(string columnName);
	long getLong(int columnIndex);
	long getLong(string columnName);
	ulong getUlong(int columnIndex);
	ulong getUlong(string columnName);
	double getDouble(int columnIndex);
	double getDouble(string columnName);
	float getFloat(int columnIndex);
	float getFloat(string columnName);
	string getString(int columnIndex);
    string getString(string columnName);
    bool wasNull();
}

interface Statement {
	ResultSet executeQuery(string query);
	int executeUpdate(string query);
	void close();
}

interface PreparedStatement : Statement {
	int executeUpdate();
	ResultSet executeQuery();

	void clearParameters();

	void setBoolean(int parameterIndex, bool x);
	void setInt(int parameterIndex, int x);
	void setShort(int parameterIndex, short x);
	void setString(int parameterIndex, short x);
}

interface Driver {
	Connection connect(string url, string[string] params);
}

interface DataSource {
	Connection getConnection();
}
