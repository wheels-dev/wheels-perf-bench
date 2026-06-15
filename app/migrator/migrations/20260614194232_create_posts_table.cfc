component extends="wheels.migrator.Migration" hint="Migration: create_posts_table" {

	function up() {
		transaction {
			try {
				t = createTable(name='posts', force='false', id='true', primaryKey='id');
				t.string(columnNames='title', default='', allowNull=true, limit='255');
				t.text(columnNames='body', default='', allowNull=true);
				t.integer(columnNames='views', default='', allowNull=true, limit='11');
				t.timestamps();
				t.create();
			} catch (any e) {
				local.exception = e;
			}

			if (StructKeyExists(local, "exception")) {
				transaction action="rollback";
				Throw(errorCode="1", detail=local.exception.detail, message=local.exception.message, type="any");
			} else {
				transaction action="commit";
			}
		}
	}

	function down() {
		transaction {
			try {
				dropTable('posts');
			} catch (any e) {
				local.exception = e;
			}

			if (StructKeyExists(local, "exception")) {
				transaction action="rollback";
				Throw(errorCode="1", detail=local.exception.detail, message=local.exception.message, type="any");
			} else {
				transaction action="commit";
			}
		}
	}

}
