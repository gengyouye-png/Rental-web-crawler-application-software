import sqlite3
from flask import Flask, jsonify, request
from db import DB_PATH, init_db

app = Flask(__name__)
app.config["JSON_AS_ASCII"] = False


@app.route("/api/houses", methods=["GET"])
def get_houses():

    city = request.args.get("city")
    district = request.args.get("district")

    init_db()

    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    cursor.execute("""
    SELECT 地區, COUNT(*)
    FROM houses
    GROUP BY 地區
    """)

    print(cursor.fetchall())

    # 篩選縣市
    if city:

        print("查詢縣市:", city)

        cursor.execute(
            '''
            SELECT *
            FROM houses
            WHERE 縣市 LIKE ?
            ''',
            (f"%{city}%",)
        )

    # 篩選行政區
    elif district:

        print("查詢地區:", district)

        cursor.execute(
            '''
            SELECT *
            FROM houses
            WHERE 地區 LIKE ?
            ''',
            (f"%{district}%",)
        )

    # 不篩選
    else:

        print("查詢全部")

        cursor.execute(
            '''
            SELECT *
            FROM houses
            '''
        )

    rows = cursor.fetchall()

    conn.close()

    houses = []

    for row in rows:
        houses.append(dict(row))

    return jsonify(houses)


if __name__ == "__main__":
    app.run(debug=True)
