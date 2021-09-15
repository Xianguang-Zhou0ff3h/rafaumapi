/**
 * HibernateD - Object-Relation Mapping for D programming language, with interface similar to Hibernate. 
 * 
 * Hibernate documentation can be found here:
 * $(LINK http://hibernate.org/docs)$(BR)
 * 
 * Source file hibernated/session.d.
 *
 * This module contains implementation of Hibernated SessionFactory and Session classes.
 * 
 * Copyright: Copyright 2013
 * License:   $(LINK www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Author:   Vadim Lopatin
 */
module hibernated.session;

import std.algorithm;
import std.conv;
import std.stdio;
import std.exception;
import std.variant;

import ddbc.core;
import ddbc.common;

import hibernated.type;
import hibernated.dialect;
import hibernated.core;
import hibernated.metadata;
import hibernated.query;

/// Factory to create HibernateD Sessions - similar to org.hibernate.SessionFactory
interface SessionFactory {
	void close();
	bool isClosed();
	Session openSession();
}

/// Session - main interface to load and persist entities -- similar to org.hibernate.Session
interface Session
{
	/// not supported in current implementation
	Transaction beginTransaction();
	/// not supported in current implementation
	void cancelQuery();
	/// not supported in current implementation
	void clear();

	/// closes session
	Connection close();

    ///Does this session contain any changes which must be synchronized with the database? In other words, would any DML operations be executed if we flushed this session?
    bool isDirty();
    /// Check if the session is still open.
    bool isOpen();
    /// Check if the session is currently connected.
    bool isConnected();
    /// Check if this instance is associated with this Session.
    bool contains(Object object);
	SessionFactory getSessionFactory();
	string getEntityName(Object object);
    /// Return the persistent instance of the given named entity with the given identifier, or null if there is no such persistent instance.
	Object get(string entityName, Variant id);
    /// Read the persistent state associated with the given identifier into the given transient instance.
    Object load(string entityName, Variant id);
    /// Read the persistent state associated with the given identifier into the given transient instance
    void load(Object obj, Variant id);
    /// Re-read the state of the given instance from the underlying database.
	void refresh(Object obj);
    /// Persist the given transient instance, first assigning a generated identifier.
	Variant save(Object obj);
	/// Persist the given transient instance.
	void persist(Object obj);
	/// Update the persistent instance with the identifier of the given detached instance.
	void update(Object object);
    /// renamed from Session.delete
    void remove(Object object);

	/// Create a new instance of Query for the given HQL query string
	Query createQuery(string queryString);
}

/// Transaction interface: TODO
interface Transaction {
}

/// Interface for usage of HQL queries.
interface Query
{
	///Get the query string.
	string 	getQueryString();
	/// Convenience method to return a single instance that matches the query, or null if the query returns no results.
	Object 	uniqueResult();
	/// Convenience method to return a single instance that matches the query, or null if the query returns no results.
	Variant[] uniqueRow();
	/// Return the query results as a List of entity objects
	Object[] list();
	/// Return the query results as a List which each row as Variant array
	Variant[][] listRows();
	
	/// Bind a value to a named query parameter (all :parameters used in query should be bound before executing query).
	Query setParameter(string name, Variant val);
}


/// Allows reaction to basic SessionFactory occurrences
interface SessionFactoryObserver {
    ///Callback to indicate that the given factory has been closed.
    void sessionFactoryClosed(SessionFactory factory);
    ///Callback to indicate that the given factory has been created and is now ready for use.
    void sessionFactoryCreated(SessionFactory factory);
}

interface EventListeners {
    // TODO:
}

interface ConnectionProvider {
}

interface Settings {
    Dialect getDialect();
    ConnectionProvider getConnectionProvider();
    bool isAutoCreateSchema();
}

interface Mapping {
    string getIdentifierPropertyName(string className);
    Type getIdentifierType(string className);
    Type getReferencedPropertyType(string className, string propertyName);
}

class Configuration {
    bool dummy;
}

/// Implementation of HibernateD session
class SessionImpl : Session {

    private bool closed;
    SessionFactoryImpl sessionFactory;
    private EntityMetaData metaData;
    Dialect dialect;
    DataSource connectionPool;
    Connection conn;

    private void checkClosed() {
        enforceEx!HibernatedException(!closed, "Session is closed");
    }

    this(SessionFactoryImpl sessionFactory, EntityMetaData metaData, Dialect dialect, DataSource connectionPool) {
        this.sessionFactory = sessionFactory;
        this.metaData = metaData;
        this.dialect = dialect;
        this.connectionPool = connectionPool;
        this.conn = connectionPool.getConnection();
    }

    override Transaction beginTransaction() {
        throw new HibernatedException("Method not implemented");
    }
    override void cancelQuery() {
        throw new HibernatedException("Method not implemented");
    }
    override void clear() {
        throw new HibernatedException("Method not implemented");
    }
    ///Does this session contain any changes which must be synchronized with the database? In other words, would any DML operations be executed if we flushed this session?
    override bool isDirty() {
        throw new HibernatedException("Method not implemented");
    }
    /// Check if the session is still open.
    override bool isOpen() {
        return !closed;
    }
    /// Check if the session is currently connected.
    override bool isConnected() {
        return !closed;
    }
    /// End the session by releasing the JDBC connection and cleaning up.
    override Connection close() {
        checkClosed();
        closed = true;
        sessionFactory.sessionClosed(this);
        conn.close();
        return null;
    }
    ///Check if this instance is associated with this Session
    override bool contains(Object object) {
        throw new HibernatedException("Method not implemented");
    }
    override SessionFactory getSessionFactory() {
        checkClosed();
        return sessionFactory;
    }
    override string getEntityName(Object object) {
        checkClosed();
        return metaData.findEntityForObject(object).name;
    }
    
    override Object get(string entityName, Variant id) {
        EntityInfo info = metaData.findEntity(entityName);
        string query = metaData.generateFindByPkForEntity(info);
        //writeln("Finder query: " ~ query);
        PreparedStatement stmt = conn.prepareStatement(query);
        scope(exit) stmt.close();
        stmt.setVariant(1, id);
        ResultSet rs = stmt.executeQuery();
        //writeln("returned rows: " ~ to!string(rs.getFetchSize()));
        scope(exit) rs.close();
        if (rs.next()) {
            Object obj = info.createEntity();
            //writeln("reading columns");
            metaData.readAllColumns(obj, rs, 1);
            //writeln("value: " ~ obj.toString);
            return obj;
        } else {
            // not found!
            return null;
        }
    }

    /// Read the persistent state associated with the given identifier into the given transient instance.
    override Object load(string entityName, Variant id) {
        Object obj = get(entityName, id);
        enforceEx!HibernatedException(obj !is null, "Entity " ~ entityName ~ " with id " ~ to!string(id) ~ " not found");
        return obj;
    }

    /// Read the persistent state associated with the given identifier into the given transient instance
    override void load(Object obj, Variant id) {
        EntityInfo info = metaData.findEntityForObject(obj);
        string query = metaData.generateFindByPkForEntity(info);
        //writeln("Finder query: " ~ query);
        PreparedStatement stmt = conn.prepareStatement(query);
        scope(exit) stmt.close();
        stmt.setVariant(1, id);
        ResultSet rs = stmt.executeQuery();
        //writeln("returned rows: " ~ to!string(rs.getFetchSize()));
        scope(exit) rs.close();
        if (rs.next()) {
            //writeln("reading columns");
            metaData.readAllColumns(obj, rs, 1);
            //writeln("value: " ~ obj.toString);
        } else {
            // not found!
            enforceEx!HibernatedException(false, "Entity " ~ info.name ~ " with id " ~ to!string(id) ~ " not found");
        }
    }

    /// Re-read the state of the given instance from the underlying database.
    override void refresh(Object obj) {
        EntityInfo info = metaData.findEntityForObject(obj);
        string query = metaData.generateFindByPkForEntity(info);
        enforceEx!HibernatedException(info.isKeySet(obj), "Cannot refresh entity " ~ info.name ~ ": no Id specified");
        Variant id = info.getKey(obj);
        //writeln("Finder query: " ~ query);
        PreparedStatement stmt = conn.prepareStatement(query);
        scope(exit) stmt.close();
        stmt.setVariant(1, id);
        ResultSet rs = stmt.executeQuery();
        //writeln("returned rows: " ~ to!string(rs.getFetchSize()));
        scope(exit) rs.close();
        if (rs.next()) {
            //writeln("reading columns");
            metaData.readAllColumns(obj, rs, 1);
            //writeln("value: " ~ obj.toString);
        } else {
            // not found!
            enforceEx!HibernatedException(false, "Entity " ~ info.name ~ " with id " ~ to!string(id) ~ " not found");
        }
    }

    /// Persist the given transient instance, first assigning a generated identifier if not assigned; returns generated value
    override Variant save(Object obj) {
        EntityInfo info = metaData.findEntityForObject(obj);
        if (!info.isKeySet(obj)) {
            if (info.getKeyProperty().generated) {
				string query = metaData.generateInsertNoKeyForEntity(info);
				PreparedStatement stmt = conn.prepareStatement(query);
				scope(exit) stmt.close();
				metaData.writeAllColumnsExceptKey(obj, stmt, 1);
				Variant generatedKey;
				stmt.executeUpdate(generatedKey);
				info.setKey(obj, generatedKey);
				return info.getKey(obj);
            } else {
                throw new HibernatedException("Key is not set and no generator is specified");
            }
        } else {
			string query = metaData.generateInsertAllFieldsForEntity(info);;
			PreparedStatement stmt = conn.prepareStatement(query);
			scope(exit) stmt.close();
			metaData.writeAllColumns(obj, stmt, 1);
			stmt.executeUpdate();
			return info.getKey(obj);
        }
    }

	/// Persist the given transient instance.
	override void persist(Object obj) {
		EntityInfo info = metaData.findEntityForObject(obj);
		enforceEx!HibernatedException(info.isKeySet(obj), "Cannot persist entity w/o key assigned");
		string query = metaData.generateInsertAllFieldsForEntity(info);;
		PreparedStatement stmt = conn.prepareStatement(query);
		scope(exit) stmt.close();
		metaData.writeAllColumns(obj, stmt, 1);
		stmt.executeUpdate();
	}

    override void update(Object obj) {
		EntityInfo info = metaData.findEntityForObject(obj);
		enforceEx!HibernatedException(info.isKeySet(obj), "Cannot persist entity w/o key assigned");
		string query = metaData.generateUpdateForEntity(info);;
		PreparedStatement stmt = conn.prepareStatement(query);
		scope(exit) stmt.close();
		metaData.writeAllColumnsExceptKey(obj, stmt, 1);
		info.keyProperty.writeFunc(obj, stmt, cast(int)(info.getPropertyCountExceptKey() + 1));
		stmt.executeUpdate();
	}

    // renamed from Session.delete since delete is D keyword
    override void remove(Object obj) {
		EntityInfo info = metaData.findEntityForObject(obj);
		string query = "DELETE FROM " ~ info.tableName ~ " WHERE " ~ info.getKeyProperty().columnName ~ "=?";
		PreparedStatement stmt = conn.prepareStatement(query);
		info.getKeyProperty().writeFunc(obj, stmt, 1);
		stmt.executeUpdate();
	}

	/// Create a new instance of Query for the given HQL query string
	Query createQuery(string queryString) {
		return new QueryImpl(this, queryString);
	}
}

/// Implementation of HibernateD SessionFactory
class SessionFactoryImpl : SessionFactory {
//    Configuration cfg;
//    Mapping mapping;
//    Settings settings;
//    EventListeners listeners;
//    SessionFactoryObserver observer;
    private bool closed;
    private EntityMetaData metaData;
    Dialect dialect;
    DataSource connectionPool;

    SessionImpl[] activeSessions;

    void sessionClosed(SessionImpl session) {
        foreach(i, item; activeSessions) {
            if (item == session) {
                remove(activeSessions, i);
            }
        }
    }

    this(EntityMetaData metaData, Dialect dialect, DataSource connectionPool) {
        this.metaData = metaData;
        this.dialect = dialect;
        this.connectionPool = connectionPool;
    }

//    this(Configuration cfg, Mapping mapping, Settings settings, EventListeners listeners, SessionFactoryObserver observer) {
//        this.cfg = cfg;
//        this.mapping = mapping;
//        this.settings = settings;
//        this.listeners = listeners;
//        this.observer = observer;
//        if (observer !is null)
//            observer.sessionFactoryCreated(this);
//    }
    private void checkClosed() {
        enforceEx!HibernatedException(!closed, "Session factory is closed");
    }

	override void close() {
        checkClosed();
        closed = true;
//        if (observer !is null)
//            observer.sessionFactoryClosed(this);
        // TODO:
    }

	bool isClosed() {
        return closed;
    }

	Session openSession() {
        checkClosed();
        SessionImpl session = new SessionImpl(this, metaData, dialect, connectionPool);
        activeSessions ~= session;
        return session;
    }
}

/// Implementation of HibernateD Query
class QueryImpl : Query
{
	SessionImpl sess;
	ParsedQuery query;
	ParameterValues params;
	this(SessionImpl sess, string queryString) {
		this.sess = sess;
		QueryParser parser = new QueryParser(sess.metaData, queryString);
		this.query = parser.makeSQL(sess.dialect);
		params = query.createParams();
	}

	///Get the query string.
	override string getQueryString() {
		return query.hql;
	}

	/// Convenience method to return a single instance that matches the query, or null if the query returns no results.
	override Object uniqueResult() {
		Object[] rows = list();
		if (rows == null)
			return null;
		enforceEx!HibernatedException(rows.length == 1, "Query returned more than one object: " ~ getQueryString());
		return rows[0];
	}

	/// Convenience method to return a single instance that matches the query, or null if the query returns no results.
	override Variant[] uniqueRow() {
		Variant[][] rows = listRows();
		if (rows == null)
			return null;
		enforceEx!HibernatedException(rows.length == 1, "Query returned more than one row: " ~ getQueryString());
		return rows[0];
	}

	/// Return the query results as a List of entity objects
	override Object[] list() {
		EntityInfo ei = query.entity;
		enforceEx!HibernatedException(ei !is null, "No entity expected in result of query " ~ getQueryString());
		params.checkAllParametersSet();
		sess.checkClosed();

		Object[] res;

		//writeln("SQL: " ~ query.sql);
		PreparedStatement stmt = sess.conn.prepareStatement(query.sql);
		scope(exit) stmt.close();
		params.applyParams(stmt);
		ResultSet rs = stmt.executeQuery();
		scope(exit) rs.close();
		while(rs.next()) {
			Object row = ei.createEntity();
			sess.metaData.readAllColumns(row, rs, 1);
			res ~= row;
		}
		return res.length > 0 ? res : null;
	}

	/// Return the query results as a List which each row as Variant array
	override Variant[][] listRows() {
		params.checkAllParametersSet();
		sess.checkClosed();
		
		Variant[][] res;
		
		//writeln("SQL: " ~ query.sql);
		PreparedStatement stmt = sess.conn.prepareStatement(query.sql);
		scope(exit) stmt.close();
		params.applyParams(stmt);
		ResultSet rs = stmt.executeQuery();
		scope(exit) rs.close();
		while(rs.next()) {
			Variant[] row = new Variant[query.colCount];
			for (int i = 1; i<=query.colCount; i++)
				row[i - 1] = rs.getVariant(i);
			res ~= row;
		}
		return res.length > 0 ? res : null;
	}
	
	/// Bind a value to a named query parameter.
	override Query setParameter(string name, Variant val) {
		params.setParameter(name, val);
		return this;
	}
}


