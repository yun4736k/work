from flask_sqlalchemy import SQLAlchemy
from flask import Flask, request, jsonify
import hashlib
import random
import json

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'mysql+pymysql://walk:1234@15.164.104.58/walkcanvas'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)

# ======================= Models =======================

class User(db.Model):
    __tablename__ = 'user'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.String(80), unique=True, nullable=False)
    password = db.Column(db.String(120), nullable=False)
    nickname = db.Column(db.String(80))
    gender = db.Column(db.String(10))

class Route(db.Model):
    __tablename__ = 'route'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.String(80), nullable=False)
    route_name = db.Column(db.String(120), nullable=False)
    route_path = db.Column(db.Text)      # JSON 문자열
    category = db.Column(db.String(80))  # NULL 허용

class FavoriteRoute(db.Model):
    __tablename__ = 'favorite_route'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.String(80), nullable=False)
    route_id = db.Column(db.Integer, db.ForeignKey('route.id'), nullable=False)

# ======================= Utils =======================

def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()

def _safe_json_loads(s, fallback):
    """문자열이면 json.loads 시도, 실패 시 fallback 반환 / 리스트면 그대로 반환"""
    if s is None:
        return fallback
    if isinstance(s, list):
        return s
    if isinstance(s, str):
        try:
            return json.loads(s)
        except Exception:
            return fallback
    return fallback

# ======================= Auth/Account =======================

def Login(ID, PW):
    user = User.query.filter_by(user_id=ID).first()
    if user and user.password == hash_password(PW):
        return {
            "status": "success",
            "message": f"환영합니다, {user.nickname}",
            "nickname": user.nickname
        }
    return {
        "status": "fail",
        "message": "등록되지 않은 계정이거나 ID 또는 비밀번호가 다릅니다."
    }

def AccountRegistration(ID, PW, NAME, SEX):
    if User.query.filter_by(user_id=ID).first():
        return "해당 ID는 이미 사용 중입니다."
    new_user = User(user_id=ID, password=hash_password(PW), nickname=NAME, gender=SEX)
    db.session.add(new_user)
    db.session.commit()
    return "계정 등록이 완료되었습니다."

def ChangeAccountInformation(ID, PW, NEW_PW, NAME, SEX):
    user = User.query.filter_by(user_id=ID).first()
    if user and user.password == hash_password(PW):
        user.password = hash_password(NEW_PW)
        user.nickname = NAME
        user.gender = SEX
        db.session.commit()
        return "계정 정보가 변경되었습니다."
    return "계정이 존재하지 않거나 기존 비밀번호가 틀렸습니다."

@app.route('/check-id', methods=['POST'])
def check_id_post():
    data = request.get_json(silent=True) or {}
    user_id = data.get("ID")
    if not user_id:
        return jsonify({"message": "ID가 제공되지 않았습니다."}), 400
    exists = User.query.filter_by(user_id=user_id).first() is not None
    return jsonify({"isDuplicate": exists}), 200

@app.route('/register', methods=['POST'])
def register():
    data = request.get_json(silent=True) or {}
    result = AccountRegistration(data.get("ID"), data.get("PW"), data.get("NAME"), data.get("SEX"))
    return jsonify({"message": result})

@app.route('/change', methods=['POST'])
def change():
    data = request.get_json(silent=True) or {}
    required = [data.get(k) for k in ("ID", "PW", "NEW_PW", "NAME", "SEX")]
    if not all(required):
        return jsonify({"message": "모든 항목이 필요합니다."}), 400
    result = ChangeAccountInformation(*required)
    return jsonify({"message": result})

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json(silent=True) or {}
    result = Login(data.get("ID"), data.get("PW"))
    return jsonify(result)

@app.route('/check-nickname', methods=['GET'])
def check_nickname_get():
    nickname = request.args.get("nickname")
    if not nickname:
        return jsonify({"message": "닉네임이 제공되지 않았습니다."}), 400
    exists = User.query.filter_by(nickname=nickname).first() is not None
    return jsonify({"exists": exists}), 200

@app.route('/check-id', methods=['GET'])
def check_id_get():
    user_id = request.args.get("ID")
    if not user_id:
        return jsonify({"message": "ID가 제공되지 않았습니다."}), 400
    exists = User.query.filter_by(user_id=user_id).first() is not None
    return jsonify({"exists": exists}), 200

# ======================= Routes (경로) =======================

@app.route('/add_route', methods=['POST'])
def add_route():
    try:
        data = request.get_json(force=True)
    except Exception as e:
        return jsonify({"message": f"잘못된 JSON 형식입니다. ({str(e)})"}), 400

    user_id = data.get("user_id")
    route_name = data.get("route_name")
    route_path = data.get("route_path")
    category = data.get("category")

    if not all([user_id, route_name, route_path]):
        return jsonify({"message": "경로명, 좌표, 사용자 ID는 필수입니다."}), 400

    try:
        route_path_list = _safe_json_loads(route_path, fallback=None)
        if not isinstance(route_path_list, list):
            raise TypeError("route_path는 리스트 형태여야 합니다.")

        json_route_path = json.dumps(route_path_list, ensure_ascii=False)

        new_route = Route(
            user_id=user_id,
            route_name=route_name,
            route_path=json_route_path,
            category=category
        )
        db.session.add(new_route)
        db.session.commit()

        return jsonify({
            "message": "경로가 성공적으로 등록되었습니다.",
            "route_name": route_name
        }), 200

    except TypeError as e:
        db.session.rollback()
        return jsonify({"message": f"경로 저장 실패: 데이터 형식 오류. ({str(e)})"}), 400
    except Exception as e:
        db.session.rollback()
        print(f"[add_route] 서버 오류: {e}")
        return jsonify({"message": f"경로 저장 실패: 서버 내부 오류. ({str(e)})"}), 500

@app.route('/recent_route', methods=['GET'])
def recent_route():
    user_id = request.args.get('user_id')
    if not user_id:
        return jsonify({"message": "user_id가 필요합니다."}), 400

    r = Route.query.filter_by(user_id=user_id).order_by(Route.id.desc()).first()
    if not r:
        return jsonify({"message": "최근 이용한 경로가 없습니다."}), 404

    user = User.query.filter_by(user_id=user_id).first()
    return jsonify({
        "route_name": r.route_name,
        "nickname": user.nickname if user else user_id,
        "route_path": _safe_json_loads(r.route_path, [])
    })

@app.route('/save_recent_route', methods=['POST'])
def save_recent_route():
    # RecentRoute 테이블이 없으므로 no-op
    return jsonify({"status": "ok"})

@app.route('/delete_route/<int:route_id>', methods=['DELETE'])
def delete_route(route_id):
    route_to_delete = Route.query.get(route_id)
    if not route_to_delete:
        return jsonify({"message": "경로를 찾을 수 없습니다."}), 404
    try:
        FavoriteRoute.query.filter_by(route_id=route_id).delete()
        db.session.delete(route_to_delete)
        db.session.commit()
        return jsonify({"message": "경로가 성공적으로 삭제되었습니다."}), 200
    except Exception as e:
        db.session.rollback()
        print(f"[delete_route] 오류: {e}")
        return jsonify({"message": f"경로 삭제 실패: 서버 내부 오류. ({str(e)})"}), 500

@app.route('/routes', methods=['GET'])
def get_routes():
    user_id = request.args.get('user_id')

    favorite_route_ids = set()
    if user_id:
        try:
            favorite_route_ids = {
                rid for (rid,) in db.session.query(FavoriteRoute.route_id)
                .filter(FavoriteRoute.user_id == user_id).all()
            }
        except Exception as e:
            print(f"[get_routes] FavoriteRoute 조회 실패: {e}")
            favorite_route_ids = set()

    routes = Route.query.filter_by(user_id=user_id).all() if user_id else Route.query.all()

    return jsonify({
        "routes": [
            {
                "id": r.id,
                "user_id": r.user_id,
                "route_name": r.route_name,
                "route_path": _safe_json_loads(r.route_path, []),
                "category": r.category,
                "is_favorite": r.id in favorite_route_ids
            }
            for r in routes
        ]
    })

@app.route('/random_user_route', methods=['GET'])
def random_user_route():
    category_param = request.args.get('category')

    if not category_param or category_param == '전체':
        all_routes = Route.query.all()
        if not all_routes:
            return jsonify({"message": "등록된 경로가 없습니다."}), 404
        route = random.choice(all_routes)
    else:
        try:
            requested_categories = json.loads(category_param)
            if not isinstance(requested_categories, list):
                requested_categories = [str(requested_categories)]
        except Exception:
            requested_categories = [c.strip() for c in category_param.split(',') if c.strip()]

        matched = []
        for r in Route.query.all():
            cats = (r.category or "")
            if any(c and c in cats for c in requested_categories):
                matched.append(r)

        if not matched:
            return jsonify({"message": "조건에 맞는 경로가 없습니다."}), 404
        route = random.choice(matched)

    user = User.query.filter_by(user_id=route.user_id).first()
    return jsonify({
        "route_name": route.route_name,
        "nickname": user.nickname if user else route.user_id,
        "route_path": _safe_json_loads(route.route_path, [])
    })

# ======================= Favorites (즐겨찾기) =======================

@app.route('/toggle_favorite', methods=['POST'])
def toggle_favorite():
    data = request.get_json(silent=True) or {}
    user_id = data.get("user_id")
    route_id = data.get("route_id")

    if not all([user_id, route_id]):
        return jsonify({"message": "user_id와 route_id는 필수입니다."}), 400

    route = Route.query.get(route_id)
    if not route:
        return jsonify({"message": "경로를 찾을 수 없습니다."}), 404

    favorite = FavoriteRoute.query.filter_by(user_id=user_id, route_id=route_id).first()

    try:
        if favorite:
            db.session.delete(favorite)
            db.session.commit()
            return jsonify({"message": "즐겨찾기가 취소되었습니다.", "is_favorite": False})
        else:
            db.session.add(FavoriteRoute(user_id=user_id, route_id=route.id))
            db.session.commit()
            return jsonify({"message": "즐겨찾기에 추가되었습니다.", "is_favorite": True})
    except Exception as e:
        db.session.rollback()
        print(f"[toggle_favorite] 오류: {e}")
        return jsonify({"message": f"즐겨찾기 처리 실패: 서버 내부 오류. ({str(e)})"}), 500

@app.route('/favorites', methods=['GET'])
def get_favorites():
    user_id = request.args.get("user_id")
    category = request.args.get("category")

    if not user_id:
        return jsonify({"message": "user_id가 제공되지 않았습니다."}), 400

    # favorite_route JOIN route
    q = db.session.query(FavoriteRoute, Route).join(
        Route, FavoriteRoute.route_id == Route.id
    ).filter(FavoriteRoute.user_id == user_id)

    if category and category != '전체':
        q = q.filter(Route.category.isnot(None)).filter(Route.category.contains(category))

    rows = q.all()

    return jsonify({
        "favorites": [
            {
                "id": route.id,  # 경로 id
                "user_id": route.user_id,
                "route_name": route.route_name,
                "route_path": _safe_json_loads(route.route_path, []),
                "category": route.category,
                "is_favorite": True
            }
            for (_fav, route) in rows
        ]
    })

@app.route('/is_favorite', methods=['POST'])
def is_favorite():
    data = request.get_json(silent=True) or {}
    user_id = data.get("user_id")
    route_id = data.get("route_id")
    route_path = data.get("route_path")  # 구버전 호환용

    if not user_id:
        return jsonify({"message": "user_id는 필수입니다."}), 400

    # 1) route_id로 확인 (권장)
    if route_id is not None:
        fav = FavoriteRoute.query.filter_by(user_id=user_id, route_id=route_id).first()
        return jsonify({"is_favorite": fav is not None})

    # 2) route_path로 확인 (구버전): favorite_route JOIN route 후 경로 비교
    if route_path is not None:
        wanted = route_path
        q = db.session.query(FavoriteRoute, Route).join(
            Route, FavoriteRoute.route_id == Route.id
        ).filter(FavoriteRoute.user_id == user_id).all()

        for (_fav, r) in q:
            if _safe_json_loads(r.route_path, []) == wanted:
                return jsonify({"is_favorite": True})
        return jsonify({"is_favorite": False})

    return jsonify({"message": "route_id 또는 route_path 중 하나는 제공되어야 합니다."}), 400

# ======================= 검색 =======================

@app.route('/search_routes', methods=['POST'])
def search_routes():
    data = request.get_json(silent=True) or {}
    categories = data.get('categories')
    if not categories:
        return jsonify({"message": "카테고리가 제공되지 않았습니다."}), 400

    if not isinstance(categories, list):
        try:
            categories = json.loads(categories)
            if not isinstance(categories, list):
                categories = [str(categories)]
        except Exception:
            categories = [str(categories)]

    routes = []
    all_routes = Route.query.all()
    for r in all_routes:
        cats = (r.category or "")
        if any(c and c in cats for c in categories):
            routes.append(r)

    if not routes:
        return jsonify({"message": "조건에 맞는 경로가 없습니다."}), 404

    result = []
    for r in routes:
        user = User.query.filter_by(user_id=r.user_id).first()
        result.append({
            "route_name": r.route_name,
            "nickname": user.nickname if user else r.user_id,
            "route_path": _safe_json_loads(r.route_path, []),
        })

    return jsonify({"routes": result})

# ====================================================================

if __name__ == '__main__':
    import os
    print("📁 현재 실행 디렉토리:", os.getcwd())

    with app.app_context():
        try:
            db.create_all()  # 없는 테이블만 생성, 기존 스키마 건드리지 않음
        except Exception as e:
            print(f"db.create_all() 경고: {e}")

        inspector = db.inspect(db.engine)
        print("📋 생성된 테이블 목록:", inspector.get_table_names())

    print("🚀 Flask 서버 실행 중")
    app.run(debug=True, host='0.0.0.0', port=5000, use_reloader=False)
