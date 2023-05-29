module ddbc.ddbctest;


void main() {

    import ddbc;
    import std.datetime : Date, DateTime;
    import std.format : format;
    import std.stdio;

    // prepare database connectivity
    auto conn = createConnection("sqlite::memory:");
    scope(exit) conn.close();
    Statement stmt = conn.createStatement();
    Statement stmt2 = conn.createStatement();
    scope(exit) stmt.close();
    // fill database with test data
    stmt.executeUpdate("DROP TABLE IF EXISTS user");
    stmt.executeUpdate("CREATE TABLE user (id INTEGER PRIMARY KEY, name VARCHAR(255) NOT NULL, flags int null, dob DATE, created DATETIME)");
    stmt.executeUpdate(`INSERT INTO user (id, name, flags, dob, created) VALUES (1, "John", 5, "1976-04-18", "2017-11-23T20:45")`);
    stmt.executeUpdate(`INSERT INTO user (id, name, flags, dob, created) VALUES (2, "Andrei", 2, "1977-09-11", "2018-02-28T13:45")`);
    stmt.executeUpdate(`INSERT INTO user (id, name, flags, dob, created) VALUES (3, "Walter", 2, "1986-03-21", "2018-03-08T10:30")`);
    stmt.executeUpdate(`INSERT INTO user (id, name, flags, dob, created) VALUES (4, "Rikki", 3, "1979-05-24", "2018-06-13T11:45")`);
    stmt.executeUpdate(`INSERT INTO user (id, name, flags, dob, created) VALUES (5, "Iain", 0, "1971-11-12", "2018-11-09T09:33")`);
    stmt.executeUpdate(`INSERT INTO user (id, name, flags, dob, created) VALUES (6, "Robert", 1, "1966-03-19", CURRENT_TIMESTAMP)`);

    // our POD object
    struct User {
        long id;
        string name;
        int flags;
        Date dob;
        DateTime created;
    }

    // class User {
    //     long id;
    //     string name;
    //     int flags;
    //     Date dob;
    //     DateTime created;
    //     override string toString() {
    //         return format("{id: %s, name: %s, flags: %s, dob: %s, created: %s}", id, name, flags, dob, created);
    //     }
    // }

    writeln("reading all user table rows");
    foreach(ref e; stmt.select!User) {
        writeln("id:", e.id, " name:", e.name, " flags:", e.flags, ", dob: ", e.dob, ", created: ", e.created);
    }

    writeln("\nreading user table rows with where and order by");
    foreach(ref e; stmt.select!User.where("id < 6").orderBy("name desc")) {
        writeln("id:", e.id, " name:", e.name, " flags:", e.flags, ", dob: ", e.dob, ", created: ", e.created);
    }

    writeln("\nreading all user table rows, but fetching only id and name (you will see default value 0 in flags field)");
    foreach(ref e; stmt.select!(User, "id", "name")) {
        writeln("id:", e.id, " name:", e.name, " flags:", e.flags, ", dob: ", e.dob, ", created: ", e.created);
    }

    writeln("\nreading all user table rows, but fetching only id and name, placing result into vars");
    long id;
    string name;
    foreach(e; stmt.select!()("SELECT id, name FROM user", id, name)) {
        writeln("id:", id, " name:", name);
    }

    writeln("\nupdating user id=1, change name to 'JB' (:))");
    foreach(ref john; stmt.select!User.where("id=1")) {
        writeln(john);
        john.name = "JB";
        stmt2.update(john);
    }
    User[1] jb_users;
    foreach(jb; stmt.select!User.where("id=1")) {
        jb_users[0] = jb;
        writeln(jb);
    }

    writeln("reading all user table rows");
    foreach(ref e; stmt.select!User) {
        writeln("id:", e.id, " name:", e.name, " flags:", e.flags, ", dob: ", e.dob, ", created: ", e.created);
    }

    writeln("\ndelete user id=1");
    stmt.remove(jb_users[0]);
    writeln("reading all user table rows");
    foreach(ref e; stmt.select!User) {
        writeln("id:", e.id, " name:", e.name, " flags:", e.flags, ", dob: ", e.dob, ", created: ", e.created);
    }

    writeln("\nGet user id=2");
    User u = stmt.get!User(2L);
    writeln(u);

    //writeln("\nGet user id=789 (throws!)");
    //try {
    //  u = stmt.get!User(789L);
    //} catch (SQLException e) {
    //  writeln("Exception thrown as expected.");
    //}

}
