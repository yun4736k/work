# app.py
from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy.exc import SQLAlchemyError, OperationalError, IntegrityError
from sqlalchemy import text, or_
import hashlib
import random
import json
import logging
import threading
import time
from datetime import datetime, timedelta
import math, json
from flask import request, jsonify

# ─────────────────────────────────────────────────────
# Flask 생성 및 기본 설정
# ─────────────────────────────────────────────────────
app = Flask(__name__)

# DB & SQLAlchemy 설정
app.config['SQLALCHEMY_DATABASE_URI'] = 'mysql+pymysql://walk:1234@3.39.231.226/walkcanvas'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['SQLALCHEMY_ENGINE_OPTIONS'] = {
    "pool_pre_ping": True,
    "pool_recycle": 280,   # 환경에 맞게 4~30분
    "pool_size": 5,
    "max_overflow": 10,
    "pool_timeout": 30,
    "future": True,
}
app.config['SQLALCHEMY_POOL_RECYCLE'] = 280
app.config['SQLALCHEMY_POOL_PRE_PING'] = True

# JSON 응답 한글 그대로
app.config['JSON_AS_ASCII'] = False

# 로깅
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)

# DB 객체
db = SQLAlchemy(app)

# ─────────────────────────────────────────────────────
# 서버 내 매핑(라벨↔ID) — 클라이언트와 동일한 정책
# ─────────────────────────────────────────────────────
ROAD_TYPE_ID_TO_NAME = {
    101: '포장도로',
    102: '비포장도로',
    103: '등산로',
    104: '짧은 산책로',
    105: '긴 산책로',
    106: '운동용 산책로',
}
# 러닝 화면에서 1~6 코드로 올 가능성 지원
ROAD_TYPE_ID_TO_NAME_ALT = {
    1: '포장도로',
    2: '비포장도로',
    3: '등산로',
    4: '짧은 산책로',
    5: '긴 산책로',
    6: '운동용 산책로',
}
TRANSPORT_ID_TO_NAME = {
    201: '걷기',
    202: '뜀걸음',
    203: '자전거',
    204: '휠체어',
    205: '유모차',
}
TRANSPORT_ID_TO_NAME_ALT = {
    1: '걷기',
    2: '뜀걸음',
    3: '자전거',
    4: '휠체어',
    5: '유모차',
}

# ─────────────────────────────────────────────────────
# 전역 에러 핸들러 & 세션 정리
# ─────────────────────────────────────────────────────
@app.errorhandler(SQLAlchemyError)
def handle_sqlalchemy_error(e):
    logging.exception("SQLAlchemy error")
    return jsonify({"message": "db_error", "detail": e.__class__.__name__}), 500

@app.errorhandler(Exception)
def handle_unexpected_error(e):
    logging.exception("Unhandled server error")
    return jsonify({"message": "server_error", "detail": e.__class__.__name__}), 500

@app.teardown_request
def remove_session(exc):
    try:
        db.session.remove()
    except Exception:
        pass

# 헬스체크
@app.route("/healthz")
def healthz():
    try:
        db.session.execute(text("SELECT 1"))
        return jsonify({"status": "ok"}), 200
    except Exception as e:
        logging.exception("healthz failed")
        return jsonify({"status": "fail", "detail": str(e)}), 500

# ─────────────────────────────────────────────────────
# DB 워밍업 (첫 요청 전에 커넥션 풀 예열)
# ─────────────────────────────────────────────────────
def warmup_db_pool():
    logging.info("🔥 Warming up DB engine & pool ...")
    try:
        with app.app_context():
            with db.engine.connect() as conn:
                conn.execute(text("SELECT 1"))
        logging.info("✅ DB warmup OK")
    except Exception:
        logging.exception("❌ DB warmup failed")

# (옵션) 주기적 keepalive: MySQL wait_timeout 회피
def _db_keepalive():
    while True:
        time.sleep(240)  # 4분
        try:
            with app.app_context():
                db.session.execute(text("SELECT 1"))
                db.session.commit()
        except Exception:
            db.session.rollback()
            logging.exception("keepalive failed; will continue")

def jaccard(a: set, b: set):
    if not a and not b: return 0.0
    return len(a & b) / len(a | b)

def exp_decay(x):
    return math.exp(-abs(x))

def recency_boost(created_at):
    days = (datetime.utcnow() - created_at).days if created_at else 180
    return max(0.2, 1.0 - (days/180.0))

def popularity_norm(fav_count, max_fav):
    if max_fav <= 0: return 0.0
    return min(1.0, (fav_count or 0) / max_fav)

def weather_fit(route_tags: set, weather_hint: str|None):
    if not weather_hint: return 0.0
    hot_pref = {'그늘', '숲길', '강변'}
    rain_pref = {'실내연결', '도심', '지하보도 인접'}
    if weather_hint == 'hot':  return 1.0 if route_tags & hot_pref else 0.0
    if weather_hint == 'rain': return 1.0 if route_tags & rain_pref else 0.0
    return 0.0


# ======================= Models =======================
class User(db.Model):
    __tablename__ = 'user'
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_id = db.Column(db.String(80), unique=True, nullable=False)
    password = db.Column(db.String(120), nullable=False)
    nickname = db.Column(db.String(80))
    gender = db.Column(db.String(10))

class Route(db.Model):
    __tablename__ = 'route'
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    # ✅ FK + CASCADE (DB 마이그레이션과 일치)
    user_id = db.Column(
        db.String(80),
        db.ForeignKey('user.user_id', ondelete='CASCADE'),
        nullable=False,
        index=True
    )
    route_name = db.Column(db.String(120), nullable=False)
    route_path = db.Column(db.Text)          # JSON 문자열
    region_id = db.Column(db.String(10))     # VARCHAR(10)
    region_label = db.Column(db.String(80))  # 예: "중구/부평동"  ← ★신규
    road_type_id = db.Column(db.String(10))  # (레거시) 단일값
    transport_id = db.Column(db.String(10))  # 단일값

    # ✅ 신규: 복수 길유형 / 라벨 저장 (JSON 문자열)
    road_type_ids = db.Column(db.Text)       # 예: "[101,102]" 또는 "[1,2]"
    category_labels = db.Column(db.Text)     # 예: ["포장도로","비포장도로"]

class FavoriteRoute(db.Model):
    __tablename__ = 'favorite_route'
    id = db.Column(db.BigInteger, primary_key=True, autoincrement=True)
    # ✅ FK + CASCADE (DB 마이그레이션과 일치)
    user_id = db.Column(
        db.String(80),
        db.ForeignKey('user.user_id', ondelete='CASCADE'),
        nullable=False,
        index=True
    )
    route_id = db.Column(
        db.Integer,
        db.ForeignKey('route.id', ondelete='CASCADE'),
        nullable=False,
        index=True
    )

    __table_args__ = (
        db.UniqueConstraint('user_id', 'route_id', name='user_route_unique'),
    )

# ======================= Utils =======================
def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()

def verify_password(plain: str, hashed: str) -> bool:
    if not plain or not hashed:
        return False
    return hash_password(plain) == hashed

def _safe_json_loads(s, fallback):
    if s is None:
        return fallback
    if isinstance(s, list):
        return s
    if isinstance(s, str):
        s = s.strip()
        if not s:
            return fallback
        try:
            return json.loads(s)
        except Exception:
            return fallback
    return fallback

def _ensure_route_extra_columns():
    """
    route 테이블에 road_type_ids, category_labels, region_label 컬럼이 없으면 추가합니다.
    """
    with db.engine.connect() as conn:
        rows = conn.execute(text("""
            SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'route'
        """)).fetchall()
        cols = {r[0] for r in rows}

        alters = []
        if 'road_type_ids' not in cols:
            alters.append("ADD COLUMN road_type_ids TEXT NULL")
        if 'category_labels' not in cols:
            alters.append("ADD COLUMN category_labels TEXT NULL")
        if 'region_label' not in cols:
            alters.append("ADD COLUMN region_label VARCHAR(80) NULL")

        if alters:
            sql = "ALTER TABLE route " + ", ".join(alters)
            logging.info("🔧 Applying migration: %s", sql)
            conn.execute(text(sql))
            logging.info("✅ Migration done")

def _normalize_list(value):
    """
    문자열(JSON/CSV) 또는 리스트를 ['값','값'] 형태 리스트로 변환
    """
    if value is None:
        return []
    if isinstance(value, list):
        return [str(x).strip() for x in value if str(x).strip()]
    if isinstance(value, str):
        s = value.strip()
        if not s:
            return []
        # JSON 배열 시도
        try:
            v = json.loads(s)
            if isinstance(v, list):
                return [str(x).strip() for x in v if str(x).strip()]
        except Exception:
            pass
        # CSV
        return [x.strip() for x in s.split(",") if x.strip()]
    return []

def _map_road_type_labels_from_ids(ids_str_list):
    """
    '101','1','포장도로' 등 섞여 들어올 수 있음 → 한글 라벨 리스트로 변환
    """
    out = []
    for raw in ids_str_list:
        label = None
        # 숫자 형태면 매핑
        try:
            n = int(raw)
            label = ROAD_TYPE_ID_TO_NAME.get(n) or ROAD_TYPE_ID_TO_NAME_ALT.get(n)
        except Exception:
            pass
        # 라벨 그대로 들어온 경우
        if label is None and raw:
            label = raw
        if label and label not in out:
            out.append(label)
    return out

def _json_or_empty(value):
    try:
        return json.loads(value) if isinstance(value, str) else (value or [])
    except Exception:
        return []

def _apply_multi_id_filter(q, single_col, multi_text_col, ids):
    """
    road_type_id 단일값 OR road_type_ids(JSON 텍스트)에 포함 여부를 동시에 필터링
    ids는 문자열 리스트 (예: ["101","102","1","2"])
    """
    if not ids:
        return q
    id_list = [str(x) for x in ids]
    like_clauses = [multi_text_col.like(f'%"{i}"%') for i in id_list]
    return q.filter(or_(single_col.in_(id_list), *like_clauses))

def _ensure_fk_cascade():
    """
    없는 FK만 안전하게 추가.
    ※ favorite_route FK 재정의는 수동 SQL로 이미 처리했다는 전제.
    """
    with db.engine.connect() as conn:
        # route.user_id → user.user_id
        fk_exists = conn.execute(text("""
            SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS
            WHERE CONSTRAINT_SCHEMA = DATABASE()
              AND CONSTRAINT_NAME = 'route_user_fk'
        """)).scalar()
        if not fk_exists:
            logging.info("🔧 Adding missing FK: route_user_fk (CASCADE)")
            conn.execute(text("""
                ALTER TABLE route
                  ADD INDEX IF NOT EXISTS idx_route_user_id (user_id),
                  ADD CONSTRAINT route_user_fk
                    FOREIGN KEY (user_id) REFERENCES user(user_id)
                    ON DELETE CASCADE
            """))
            logging.info("✅ FK route_user_fk added")

        # recent_route.user_id → user.user_id (있을 때만)
        fk_exists = conn.execute(text("""
            SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS
            WHERE CONSTRAINT_SCHEMA = DATABASE()
              AND CONSTRAINT_NAME = 'recent_route_user_fk'
        """)).scalar()
        if not fk_exists:
            tbl_exists = conn.execute(text("""
                SELECT COUNT(*) FROM information_schema.TABLES
                WHERE TABLE_SCHEMA = DATABASE()
                  AND TABLE_NAME = 'recent_route'
            """)).scalar()
            if tbl_exists:
                logging.info("🔧 Adding missing FK: recent_route_user_fk (CASCADE)")
                conn.execute(text("""
                    ALTER TABLE recent_route
                      ADD INDEX IF NOT EXISTS idx_recent_user_id (user_id),
                      ADD CONSTRAINT recent_route_user_fk
                        FOREIGN KEY (user_id) REFERENCES user(user_id)
                        ON DELETE CASCADE
                """))
                logging.info("✅ FK recent_route_user_fk added")

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

# ✅ 계정 삭제(하드 삭제): 비밀번호 검증 + FK CASCADE로 하위 전부 삭제
@app.route('/users/<string:user_id>', methods=['DELETE'])
def delete_user(user_id):
    data = request.get_json(silent=True) or {}
    password = (data.get("password") or "").strip()

    try:
        user = User.query.filter_by(user_id=user_id).first()
        if not user:
            return jsonify({"ok": False, "message": "존재하지 않는 사용자"}), 404

        if not verify_password(password, user.password):
            return jsonify({"ok": False, "message": "비밀번호가 올바르지 않습니다."}), 401

        db.session.delete(user)   # FK CASCADE에 의해 routes/favorites/recent가 자동 삭제
        db.session.commit()
        return jsonify({"ok": True, "message": "계정을 삭제했습니다."}), 200

    except IntegrityError as e:
        db.session.rollback()
        return jsonify({"ok": False, "message": "무결성 오류로 삭제 실패", "detail": str(e.orig)}), 409
    except (SQLAlchemyError, OperationalError) as e:
        db.session.rollback()
        return jsonify({"ok": False, "message": "DB 오류로 삭제 실패", "detail": str(e)}), 500
    except Exception as e:
        db.session.rollback()
        return jsonify({"ok": False, "message": "서버 오류로 삭제 실패", "detail": str(e)}), 500

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
    region_id = data.get("region_id")
    region_label = data.get("region_label")  # ★ 신규: "중구/부평동" 등

    # 하위호환 단일값
    road_type_id = data.get("road_type_id")
    transport_id = data.get("transport_id")

    # ✅ 신규 입력(복수/라벨 모두 허용)
    road_type_ids_raw = data.get("road_type_ids") or data.get("road_types")
    category_labels_raw = data.get("category_labels") or data.get("categories")

    if not all([user_id, route_name, route_path]):
        return jsonify({"message": "경로명, 좌표, 사용자 ID는 필수입니다."}), 400

    try:
        route_path_list = _safe_json_loads(route_path, fallback=None)
        if not isinstance(route_path_list, list):
            raise TypeError("route_path는 리스트 형태여야 합니다.")

        # 🔁 길 유형 복수값 정규화
        road_type_ids_list = _normalize_list(road_type_ids_raw)
        category_labels_list = _normalize_list(category_labels_raw)

        # 라벨이 없고 ID만 있는 경우 라벨 유도
        if not category_labels_list and road_type_ids_list:
            category_labels_list = _map_road_type_labels_from_ids(road_type_ids_list)

        # 단일 road_type_id만 있는 경우, 복수값에도 반영
        if (not road_type_ids_list) and road_type_id:
            road_type_ids_list = [str(road_type_id)]
            if not category_labels_list:
                category_labels_list = _map_road_type_labels_from_ids(road_type_ids_list)

        new_route = Route(
            user_id=user_id,
            route_name=route_name,
            route_path=json.dumps(route_path_list, ensure_ascii=False),
            region_id=str(region_id) if region_id is not None else None,
            region_label=str(region_label) if region_label else None,  # ★ 저장
            road_type_id=str(road_type_id) if road_type_id is not None else None,
            transport_id=str(transport_id) if transport_id is not None else None,
            road_type_ids=json.dumps(road_type_ids_list, ensure_ascii=False) if road_type_ids_list else None,
            category_labels=json.dumps(category_labels_list, ensure_ascii=False) if category_labels_list else None,
        )
        db.session.add(new_route)
        db.session.commit()

        return jsonify({
            "message": "경로가 성공적으로 등록되었습니다.",
            "route_id": new_route.id,
            "route_name": route_name,
            "region_id": new_route.region_id,
            "region_label": new_route.region_label,  # ★ 응답 포함
            "road_type_ids": _json_or_empty(new_route.road_type_ids or "[]"),
            "category_labels": _json_or_empty(new_route.category_labels or "[]"),
        }), 200

    except TypeError as e:
        db.session.rollback()
        return jsonify({"message": f"경로 저장 실패: 데이터 형식 오류. ({str(e)})"}), 400
    except Exception as e:
        db.session.rollback()
        logging.exception("[add_route] 서버 오류")
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
        "route_path": _safe_json_loads(r.route_path, []),
        "polyline": _safe_json_loads(r.route_path, []),
        "region_id": r.region_id,
        "region_label": r.region_label,   # ★
        "road_type_id": r.road_type_id,
        "transport_id": r.transport_id,
        # ✅ 확장 필드
        "road_type_ids": _json_or_empty(r.road_type_ids or "[]"),
        "category_labels": _json_or_empty(r.category_labels or "[]"),
    })

@app.route('/save_recent_route', methods=['POST'])
def save_recent_route():
    return jsonify({"status": "ok"})

@app.route('/delete_route/<int:route_id>', methods=['DELETE'])
def delete_route(route_id):
    route_to_delete = Route.query.get(route_id)
    if not route_to_delete:
        return jsonify({"message": "경로를 찾을 수 없습니다."}), 404
    try:
        # favorite_route는 FK CASCADE로 자동 정리되지만, 아래 한 줄은 무해한 보조장치
        db.session.query(FavoriteRoute).filter_by(route_id=route_id).delete()
        db.session.delete(route_to_delete)
        db.session.commit()
        return jsonify({"message": "경로가 성공적으로 삭제되었습니다."}), 200
    except Exception as e:
        db.session.rollback()
        logging.exception("[delete_route] 오류")
        return jsonify({"message": f"경로 삭제 실패: 서버 내부 오류. ({str(e)})"}), 500

@app.route('/routes', methods=['GET'])
def get_routes():
    user_id = request.args.get('user_id')
    if not user_id:
        return jsonify({"message": "user_id가 필요합니다."}), 400

    try:
        favorite_route_ids = {
            rid for (rid,) in db.session.query(FavoriteRoute.route_id)
            .filter(FavoriteRoute.user_id == user_id).all()
        }
    except Exception as e:
        logging.exception("[get_routes] FavoriteRoute 조회 실패")
        favorite_route_ids = set()

    fav_counts = dict(
        db.session.query(FavoriteRoute.route_id, db.func.count(FavoriteRoute.id))
        .group_by(FavoriteRoute.route_id)
        .all()
    )

    routes = Route.query.filter_by(user_id=user_id).all()

    return jsonify({
        "routes": [
            {
                "id": r.id,
                "user_id": r.user_id,
                "route_name": r.route_name,
                "route_path": _safe_json_loads(r.route_path, []),
                "polyline": _safe_json_loads(r.route_path, []),
                "region_id": r.region_id,
                "region_label": r.region_label,  # ★
                "road_type_id": r.road_type_id,
                "transport_id": r.transport_id,
                "road_type_ids": _json_or_empty(r.road_type_ids or "[]"),
                "category_labels": _json_or_empty(r.category_labels or "[]"),
                "is_favorite": r.id in favorite_route_ids,
                "favorite_count": fav_counts.get(r.id, 0)
            }
            for r in routes
        ]
    }), 200

@app.route('/random_user_route', methods=['GET'])
def random_user_route():
    def _parse_list_param(param_str):
        if not param_str:
            return None
        try:
            v = json.loads(param_str)
            if isinstance(v, list):
                return [str(x) for x in v]
        except Exception:
            pass
        out = [x.strip() for x in param_str.split(',') if x.strip()]
        return [str(x) for x in out] if out else None

    region_ids = _parse_list_param(request.args.get('region_id'))
    road_type_ids = _parse_list_param(request.args.get('road_type_id'))
    transport_ids = _parse_list_param(request.args.get('transport_id'))

    q = Route.query
    if region_ids:
        q = q.filter(Route.region_id.in_(region_ids))
    if transport_ids:
        q = q.filter(Route.transport_id.in_(transport_ids))
    if road_type_ids:
        q = _apply_multi_id_filter(q, Route.road_type_id, Route.road_type_ids, road_type_ids)

    candidates = q.all()
    if not candidates:
        return jsonify({"message": "조건에 맞는 경로가 없습니다."}), 404

    route = random.choice(candidates)
    user = User.query.filter_by(user_id=route.user_id).first()
    return jsonify({
        "route_name": route.route_name,
        "nickname": user.nickname if user else route.user_id,
        "route_path": _safe_json_loads(route.route_path, []),
        "polyline": _safe_json_loads(route.route_path, []),
        "region_id": route.region_id,
        "region_label": route.region_label,  # ★
        "road_type_id": route.road_type_id,
        "transport_id": route.transport_id,
        # ✅ 확장 필드
        "road_type_ids": _json_or_empty(route.road_type_ids or "[]"),
        "category_labels": _json_or_empty(route.category_labels or "[]"),
    }), 200

# ======================= Favorites =======================
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
            new_count = db.session.query(db.func.count(FavoriteRoute.id))\
                                  .filter(FavoriteRoute.route_id == route_id).scalar()
            return jsonify({
                "message": "즐겨찾기가 취소되었습니다.",
                "is_favorite": False,
                "favorite_count": int(new_count or 0)
            })
        else:
            db.session.add(FavoriteRoute(user_id=user_id, route_id=route.id))
            db.session.commit()
            new_count = db.session.query(db.func.count(FavoriteRoute.id))\
                                  .filter(FavoriteRoute.route_id == route_id).scalar()
            return jsonify({
                "message": "즐겨찾기에 추가되었습니다.",
                "is_favorite": True,
                "favorite_count": int(new_count or 0)
            })
    except Exception as e:
        db.session.rollback()
        logging.exception("[toggle_favorite] 오류")
        return jsonify({"message": f"즐겨찾기 처리 실패: 서버 내부 오류. ({str(e)})"}), 500

@app.route('/favorites', methods=['GET'])
def get_favorites():
    user_id = request.args.get("user_id")
    if not user_id:
        return jsonify({"message": "user_id가 제공되지 않았습니다."}), 400

    def _parse_list_param(param_str):
        if not param_str:
            return None
        try:
            v = json.loads(param_str)
            if isinstance(v, list):
                return [str(x) for x in v]
        except Exception:
            pass
        out = [x.strip() for x in param_str.split(',') if x.strip()]
        return [str(x) for x in out] if out else None

    region_ids = _parse_list_param(request.args.get('region_id'))
    road_type_ids = _parse_list_param(request.args.get('road_type_id'))
    transport_ids = _parse_list_param(request.args.get('transport_id'))

    q = db.session.query(FavoriteRoute, Route).join(
        Route, FavoriteRoute.route_id == Route.id
    ).filter(FavoriteRoute.user_id == user_id)

    if region_ids:
        q = q.filter(Route.region_id.in_(region_ids))
    if transport_ids:
        q = q.filter(Route.transport_id.in_(transport_ids))
    if road_type_ids:
        # join 쿼리에서도 road_type_ids LIKE 매칭
        like_clauses = [Route.road_type_ids.like(f'%"{i}"%') for i in road_type_ids]
        q = q.filter(or_(Route.road_type_id.in_(road_type_ids), *like_clauses))

    rows = q.all()

    fav_counts = dict(
        db.session.query(FavoriteRoute.route_id, db.func.count(FavoriteRoute.id))
        .group_by(FavoriteRoute.route_id)
        .all()
    )

    return jsonify({
        "favorites": [
            {
                "id": route.id,
                "user_id": route.user_id,
                "route_name": route.route_name,
                "route_path": _safe_json_loads(route.route_path, []),
                "polyline": _safe_json_loads(route.route_path, []),
                "region_id": route.region_id,
                "region_label": route.region_label,  # ★
                "road_type_id": route.road_type_id,
                "transport_id": route.transport_id,
                "road_type_ids": _json_or_empty(route.road_type_ids or "[]"),
                "category_labels": _json_or_empty(route.category_labels or "[]"),
                "is_favorite": True,
                "favorite_count": fav_counts.get(route.id, 0)
            }
            for (_fav, route) in rows
        ]
    }), 200

@app.route('/is_favorite', methods=['POST'])
def is_favorite():
    data = request.get_json(silent=True) or {}
    user_id = data.get("user_id")
    route_id = data.get("route_id")
    route_path = data.get("route_path")

    if not user_id:
        return jsonify({"message": "user_id는 필수입니다."}), 400

    if route_id is not None:
        fav = FavoriteRoute.query.filter_by(user_id=user_id, route_id=route_id).first()
        return jsonify({"is_favorite": fav is not None}), 200

    if route_path is not None:
        wanted = route_path
        q = db.session.query(FavoriteRoute, Route).join(
            Route, FavoriteRoute.route_id == Route.id
        ).filter(FavoriteRoute.user_id == user_id).all()

        for (_fav, r) in q:
            if _safe_json_loads(r.route_path, []) == wanted:
                return jsonify({"is_favorite": True}), 200
        return jsonify({"is_favorite": False}), 200

    return jsonify({"message": "route_id 또는 route_path 중 하나는 제공되어야 합니다."}), 400

# ======================= 검색 =======================
@app.route('/search_routes', methods=['POST'])
def search_routes():
    started = time.time()
    try:
        data = request.get_json(silent=True) or {}

        categories = data.get('categories')
        if not isinstance(categories, dict):
            return jsonify({"message": "카테고리가 제공되지 않았거나 형식이 올바르지 않습니다."}), 400

        only_fav = bool(data.get('onlyFavorites', False))
        fav_user_id = data.get('user_id')

        q = Route.query

        region_ids = categories.get('지역', [])
        road_type_ids = categories.get('길 유형', [])
        transport_ids = categories.get('이동수단', [])

        if region_ids:
            q = q.filter(Route.region_id.in_([str(x) for x in region_ids]))
        if transport_ids:
            q = q.filter(Route.transport_id.in_([str(x) for x in transport_ids]))
        if road_type_ids:
            q = _apply_multi_id_filter(q, Route.road_type_id, Route.road_type_ids, [str(x) for x in road_type_ids])

        if only_fav:
            if not fav_user_id:
                return jsonify({"message": "즐겨찾기 필터에는 user_id가 필요합니다."}), 400
            sub = db.session.query(FavoriteRoute.route_id).filter(
                FavoriteRoute.user_id == fav_user_id
            ).subquery()
            q = q.filter(Route.id.in_(sub))

        routes = q.all()
        if not routes:
            return jsonify({"message": "조건에 맞는 경로가 없습니다."}), 404

        fav_counts = dict(
            db.session.query(FavoriteRoute.route_id, db.func.count(FavoriteRoute.id))
            .group_by(FavoriteRoute.route_id)
            .all()
        )

        user_favs = set()
        if fav_user_id:
            user_favs = {
                rid for (rid,) in db.session.query(FavoriteRoute.route_id)
                .filter(FavoriteRoute.user_id == fav_user_id).all()
            }

        result = []
        for r in routes:
            user = User.query.filter_by(user_id=r.user_id).first()
            result.append({
                "id": r.id,
                "route_name": r.route_name,
                "nickname": user.nickname if user else r.user_id,
                "route_path": _safe_json_loads(r.route_path, []),
                "polyline": _safe_json_loads(r.route_path, []),
                "region_id": r.region_id,
                "region_label": r.region_label,  # ★
                "road_type_id": r.road_type_id,
                "transport_id": r.transport_id,
                "road_type_ids": _json_or_empty(r.road_type_ids or "[]"),
                "category_labels": _json_or_empty(r.category_labels or "[]"),
                "favorite_count": fav_counts.get(r.id, 0),
                "is_favorite": r.id in user_favs
            })

        return jsonify({"routes": result}), 200

    except (SQLAlchemyError, OperationalError):
        logging.exception("/search_routes DB error")
        return jsonify({"message": "db_error"}), 500
    except Exception:
        logging.exception("/search_routes server error")
        return jsonify({"message": "server_error"}), 500
    finally:
        took = time.time() - started
        logging.info(f"/search_routes took {took:.3f}s")

# ====================================================================
if __name__ == '__main__':
    import os
    print("📁 현재 실행 디렉토리:", os.getcwd())

    with app.app_context():
        try:
            db.create_all()
        except Exception as e:
            print(f"db.create_all() 경고: {e}")

        inspector = db.inspect(db.engine)
        print("📋 생성된 테이블 목록:", inspector.get_table_names())

        # 🔧 새 컬럼 보장 (road_type_ids, category_labels, region_label)
        _ensure_route_extra_columns()

        # 🔧 (없는 FK만) 보정
        _ensure_fk_cascade()

        # 🔥 워밍업
        warmup_db_pool()

    # ✅ DB/앱 초기화가 끝난 뒤 keepalive 시작
    threading.Thread(target=_db_keepalive, daemon=True).start()

    print("🚀 Flask 서버 실행 중 (region_label enabled)")
    app.run(debug=True, host='0.0.0.0', port=5000, use_reloader=False)
