from flask_sqlalchemy import SQLAlchemy
from flask import Flask, request, jsonify
from datetime import datetime
import hashlib
import random
import json

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'mysql+pymysql://walk:1234@15.164.104.58/walkcanvas' 
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.String(80), unique=True, nullable=False)
    password = db.Column(db.String(120), nullable=False)
    nickname = db.Column(db.String(80))
    gender = db.Column(db.String(10))

class Route(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.String(80), nullable=False)
    route_name = db.Column(db.String(120), nullable=False)
    route_path = db.Column(db.Text)
    category = db.Column(db.String(80))
    like_count = db.Column(db.Integer, default=0)
    favorite_count = db.Column(db.Integer, default=0)

class Favorite(db.Model):
    __tablename__ = 'favorite'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.String(80), nullable=False)
    
    route_name = db.Column(db.String(120), nullable=False)
    route_path = db.Column(db.Text)
    category = db.Column(db.String(80))
    route_id = db.Column(db.Integer, nullable=False)

class RecentRoute(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.String(80), unique=True, nullable=False)
    route_name = db.Column(db.String(120), nullable=False)
    route_path = db.Column(db.Text)
    category = db.Column(db.String(80))

def hash_password(password):
    return hashlib.sha256(password.encode()).hexdigest()

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
def check_id():
    data = request.get_json()
    user_id = data.get("ID")
    if not user_id:
        return jsonify({"message": "ID가 제공되지 않았습니다."}), 400
    exists = User.query.filter_by(user_id=user_id).first() is not None
    return jsonify({"isDuplicate": exists}), 200

@app.route('/register', methods=['POST'])
def register():
    data = request.json
    print("📥 회원가입 요청 수신됨: ", data)
    result = AccountRegistration(data["ID"], data["PW"], data["NAME"], data["SEX"])
    print("📤 회원가입 처리 결과: ", result)
    return jsonify({"message": result})

@app.route('/change', methods=['POST'])
def change():
    data = request.json
    required = [data.get(k) for k in ("ID", "PW", "NEW_PW", "NAME", "SEX")]
    if not all(required):
        return jsonify({"message": "모든 항목이 필요합니다."}), 400
    result = ChangeAccountInformation(*required)
    return jsonify({"message": result})

@app.route('/login', methods=['POST'])
def login():
    data = request.json
    result = Login(data["ID"], data["PW"])
    return jsonify(result)

@app.route('/add_route', methods=['POST'])
def add_route():
    # 1. 클라이언트로부터 JSON 데이터 수신
    try:
        data = request.get_json()
        user_id = data.get("user_id")
        route_name = data.get("route_name")
        route_path = data.get("route_path")
        category = data.get("category")
    except Exception as e:
        # JSON 형식이 잘못된 경우
        return jsonify({"message": f"잘못된 JSON 형식입니다. ({str(e)})"}), 400

    # 2. 필수 데이터 유효성 검사
    if not all([user_id, route_name, route_path]):
        return jsonify({"message": "경로명, 좌표, 사용자 ID는 필수입니다."}), 400
    
    

    try:
        print(f"📥 수신된 route_path 데이터 타입: {type(route_path)}")
        print(f"📥 수신된 route_path 데이터: {route_path}")
        # 3. 데이터베이스에 경로 저장
        # route_path가 유효한 리스트인지 확인하고 JSON으로 변환
        if not isinstance(route_path, list):
            raise TypeError("route_path는 리스트 형태여야 합니다.")
        
        json_route_path = json.dumps(route_path)

        # Route 테이블에 새 경로 추가
        db.session.add(Route(
            user_id=user_id,
            route_name=route_name,
            route_path=json_route_path,
            category=category
        ))

        # 4. RecentRoute 테이블 업데이트
        recent = RecentRoute.query.filter_by(user_id=user_id).first()
        if recent:
            recent.route_name = route_name
            recent.route_path = json_route_path
            recent.category = category
        else:
            db.session.add(RecentRoute(
                user_id=user_id,
                route_name=route_name,
                route_path=json_route_path,
                category=category
            ))

        # 5. 모든 변경사항 커밋
        db.session.commit()
        return jsonify({
            "message": "경로가 성공적으로 등록되었습니다.",
            "route_name": route_name
        }), 200

    except TypeError as e:
        # `route_path` 데이터 형식 오류 처리
        db.session.rollback()
        return jsonify({
            "message": f"경로 저장 실패: 데이터 형식 오류. ({str(e)})"
        }), 400

    except Exception as e:
        # 기타 예상치 못한 서버 오류 처리 (DB 연결, 기타)
        db.session.rollback()
        print(f"경로 저장 중 심각한 서버 오류 발생: {e}")
        return jsonify({
            "message": f"경로 저장 실패: 서버 내부 오류. ({str(e)})"
        }), 500

@app.route('/recent_route', methods=['GET'])
def recent_route():
    user_id = request.args.get('user_id')
    recent = RecentRoute.query.filter_by(user_id=user_id).first()
    if recent:
        user = User.query.filter_by(user_id=user_id).first()
        return jsonify({
            "route_name": recent.route_name,
            "nickname": user.nickname if user else user_id,
            "route_path": json.loads(recent.route_path)
        })
    return jsonify({"message": "최근 이용한 경로가 없습니다."}), 404

# app.py

@app.route('/delete_route/<int:route_id>', methods=['DELETE'])
def delete_route(route_id):
    """
    주어진 ID에 해당하는 경로를 데이터베이스에서 삭제합니다.
    """
    print(f"📥 경로 삭제 요청 수신: ID={route_id}")
    
    # 1. 주어진 ID로 경로를 찾습니다.
    route_to_delete = Route.query.get(route_id)
    
    # 2. 경로가 존재하는지 확인합니다.
    if route_to_delete:
        try:
            # 3. 경로가 존재하면 삭제하고 커밋합니다.
            db.session.delete(route_to_delete)
            db.session.commit()
            print(f"✅ 경로 ID {route_id} 삭제 완료")
            return jsonify({"message": "경로가 성공적으로 삭제되었습니다."}), 200
        except Exception as e:
            # 4. 삭제 중 오류 발생 시 롤백합니다.
            db.session.rollback()
            print(f"❌ 경로 삭제 중 오류 발생: {e}")
            return jsonify({"message": f"경로 삭제 실패: 서버 내부 오류. ({str(e)})"}), 500
    
    # 5. 해당 ID의 경로를 찾을 수 없으면 404를 반환합니다.
    print(f"⚠️ 경로 ID {route_id}를 찾을 수 없음")
    return jsonify({"message": "경로를 찾을 수 없습니다."}), 404

@app.route('/routes', methods=['GET'])
def get_routes():
    # 1. URL 쿼리 파라미터에서 user_id를 가져옵니다.
    user_id = request.args.get('user_id')

    # 2. 현재 사용자의 모든 즐겨찾기 경로 ID를 미리 조회하여 집합(set)으로 만듭니다.
    #    이렇게 하면 각 경로를 순회하며 데이터베이스를 반복적으로 조회하는 비효율을 막을 수 있습니다.
    favorite_route_ids = {fav.route_id for fav in Favorite.query.filter_by(user_id=user_id).all()}

    # 3. user_id가 있으면 해당 사용자의 경로만 조회합니다.
    if user_id:
        routes = Route.query.filter_by(user_id=user_id).all()
    else:
        # user_id가 없으면 모든 경로를 반환합니다. (선택사항)
        routes = Route.query.all()
        
    # 4. 각 경로 객체를 딕셔너리로 변환하여 JSON 응답을 생성합니다.
    #    이때, 'is_favorite' 필드를 추가합니다.
    return jsonify({
        "routes": [
            {
                "id": r.id,
                "user_id": r.user_id,
                "route_name": r.route_name,
                "route_path": json.loads(r.route_path),
                "category": r.category,
                "like_count": r.like_count,
                "favorite_count": r.favorite_count,
                # ✨ 핵심 수정 부분: route.id가 즐겨찾기 ID 집합에 있는지 확인하여 True/False를 반환
                "is_favorite": r.id in favorite_route_ids  
            }
            for r in routes
        ]
    })

@app.route('/random_user_route', methods=['GET'])
def random_user_route():
    category_param = request.args.get('category')
    print(">>> 받은 카테고리:", category_param)

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
        except:
            requested_categories = [c.strip() for c in category_param.split(',') if c.strip()]

        matched_routes = []
        for route in Route.query.all():
            try:
                route_categories = json.loads(route.category)
                if isinstance(route_categories, str):
                    route_categories = [route_categories]
            except:
                route_categories = [route.category]

            if any(cat in route_categories for cat in requested_categories):
                matched_routes.append(route)

        if not matched_routes:
            return jsonify({"message": "조건에 맞는 경로가 없습니다."}), 404
        route = random.choice(matched_routes)

    user = User.query.filter_by(user_id=route.user_id).first()
    return jsonify({
        "route_name": route.route_name,
        "nickname": user.nickname if user else route.user_id,
        "route_path": json.loads(route.route_path)
    })

@app.route('/toggle_favorite', methods=['POST'])
def toggle_favorite():
    data = request.get_json()
    user_id = data.get("user_id")
    route_id = data.get("route_id")

    if not all([user_id, route_id]):
        return jsonify({"message": "user_id와 route_id는 필수입니다."}), 400

    favorite = Favorite.query.filter_by(user_id=user_id, route_id=route_id).first()
    route = Route.query.get(route_id)

    if not route:
        return jsonify({"message": "경로를 찾을 수 없습니다."}), 404

    if favorite:
        # 이미 즐겨찾기에 있다면 삭제 (즐겨찾기 해제)
        db.session.delete(favorite)
        route.favorite_count = max(0, (route.favorite_count or 1) - 1)
        db.session.commit()
        return jsonify({"message": "즐겨찾기가 취소되었습니다.", "is_favorite": False})
    else:
        # 즐겨찾기에 없다면 추가 (즐겨찾기 설정)
        new_fav = Favorite(
            user_id=user_id,
            route_id=route.id,
            route_name=route.route_name,
            route_path=route.route_path,
            category=route.category
        )
        db.session.add(new_fav)
        route.favorite_count = (route.favorite_count or 0) + 1
        db.session.commit()
        return jsonify({"message": "즐겨찾기에 추가되었습니다.", "is_favorite": True})
    
@app.route('/favorites', methods=['GET'])
def get_favorites():
    user_id = request.args.get("user_id")
    category = request.args.get("category")

    query = Favorite.query.filter_by(user_id=user_id)
    if category and category != '전체':
        query = query.filter_by(category=category)

    favs = query.all()
    return jsonify({
        "favorites": [
            {
                "route_name": f.route_name,
                "route_path": json.loads(f.route_path),
                "category": f.category
            }
            for f in favs
        ]
    })

@app.route('/is_favorite', methods=['POST'])
def is_favorite():
    data = request.get_json()
    user_id = data.get("user_id")
    route_path = data.get("route_path")
    favs = Favorite.query.filter_by(user_id=user_id).all()
    for fav in favs:
        if json.loads(fav.route_path) == route_path:
            return jsonify({"is_favorite": True})
    return jsonify({"is_favorite": False})

@app.route('/save_recent_route', methods=['POST'])
def save_recent_route():
    data = request.get_json()
    user_id = data.get("user_id")
    route_name = data.get("route_name")
    route_path = data.get("route_path")
    recent = RecentRoute.query.filter_by(user_id=user_id).first()
    if recent:
        recent.route_name = route_name
        recent.route_path = json.dumps(route_path)
    else:
        db.session.add(RecentRoute(user_id=user_id, route_name=route_name, route_path=json.dumps(route_path)))
    db.session.commit()
    return jsonify({"status": "ok"})

@app.route('/check-nickname', methods=['GET'])
def check_nickname():
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

@app.route('/all_favorites', methods=['GET'])
def all_favorites():
    user_id = request.args.get("user_id")
    if not user_id:
        return jsonify({"message": "user_id가 제공되지 않았습니다."}), 400

    favs = Favorite.query.filter_by(user_id=user_id).all()

    return jsonify({
        "favorites": [
            {
                "route_name": f.route_name,
                "route_path": json.loads(f.route_path),
                "category": f.category
            }
            for f in favs
        ]
    })

@app.route('/all_user_routes', methods=['GET'])
def all_user_routes():
    category_param = request.args.get('category')

    if not category_param or category_param == '전체':
        routes = Route.query.all()
    else:
        try:
            requested_categories = json.loads(category_param)
            if not isinstance(requested_categories, list):
                requested_categories = [str(requested_categories)]
        except:
            requested_categories = [c.strip() for c in category_param.split(',') if c.strip()]

        routes = []
        for route in Route.query.all():
            try:
                route_categories = json.loads(route.category)
                if isinstance(route_categories, str):
                    route_categories = [route_categories]
            except:
                route_categories = [route.category]

            if any(cat in route_categories for cat in requested_categories):
                routes.append(route)

    result = []
    for r in routes:
        user = User.query.filter_by(user_id=r.user_id).first()
        result.append({
            "route_name": r.route_name,
            "nickname": user.nickname if user else r.user_id,
            "route_path": json.loads(r.route_path),
            "like_count": r.like_count,
            "favorite_count": r.favorite_count
        })

    return jsonify(result)


# ======================= 새로 추가된 검색 API =======================
@app.route('/search_routes', methods=['POST'])
def search_routes():
    data = request.get_json()
    categories = data.get('categories')  # 리스트 형태로 기대

    if not categories:
        return jsonify({"message": "카테고리가 제공되지 않았습니다."}), 400

    routes = []
    all_routes = Route.query.all()

    for route in all_routes:
        try:
            route_categories = json.loads(route.category)
            if isinstance(route_categories, str):
                route_categories = [route_categories]
        except:
            route_categories = [route.category]

        if any(cat in route_categories for cat in categories):
            routes.append(route)

    if not routes:
        return jsonify({"message": "조건에 맞는 경로가 없습니다."}), 404

    result = []
    for r in routes:
        user = User.query.filter_by(user_id=r.user_id).first()
        result.append({
            "route_name": r.route_name,
            "nickname": user.nickname if user else r.user_id,
            "route_path": json.loads(r.route_path),
            "like_count": r.like_count,
            "favorite_count": r.favorite_count
        })

    return jsonify({"routes": result})

# ====================================================================

if __name__ == '__main__':
    import os
    print("📁 현재 실행 디렉토리:", os.getcwd())
    print("📂 mydb.db 절대경로:", os.path.abspath("mydb.db"))

    with app.app_context():
        print("📌 db.create_all() 실행 시도 중...")
        db.create_all()
        print("✅ db.create_all() 완료됨")

        inspector = db.inspect(db.engine)
        print("📋 생성된 테이블 목록:", inspector.get_table_names())

    print("🚀 Flask 서버 실행 중")
    app.run(debug=True, host='0.0.0.0', port=5000, use_reloader=False)