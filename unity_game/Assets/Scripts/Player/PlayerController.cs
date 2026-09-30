using UnityEngine;

namespace Refugee1950
{
    /// <summary>
    /// 위에서 내려다보는(탑다운) 2D 이동. 방향키 / WASD로 움직이고 Shift로 뛴다.
    /// Rigidbody2D(Gravity Scale 0, Freeze Rotation Z)와 Collider2D가 필요하다.
    /// </summary>
    [RequireComponent(typeof(Rigidbody2D))]
    public class PlayerController : MonoBehaviour
    {
        public float walkSpeed = 3f;
        public float runSpeed = 5f;

        [Tooltip("선택: Animator에 MoveX, MoveY, Speed 파라미터를 만들어 두면 걷기 애니메이션이 재생된다.")]
        public Animator animator;

        Rigidbody2D body;
        Vector2 input;

        /// <summary>마지막으로 바라본 방향 (상호작용 판정에 사용)</summary>
        public Vector2 Facing { get; private set; } = Vector2.down;

        void Awake()
        {
            body = GetComponent<Rigidbody2D>();
            body.gravityScale = 0f;
            body.freezeRotation = true;
        }

        void Update()
        {
            bool locked = GameManager.Instance != null && GameManager.Instance.IsInputLocked;
            input = locked ? Vector2.zero : new Vector2(Input.GetAxisRaw("Horizontal"), Input.GetAxisRaw("Vertical"));
            if (input.sqrMagnitude > 1f) input.Normalize();
            if (input != Vector2.zero) Facing = input;

            if (animator != null)
            {
                animator.SetFloat("MoveX", Facing.x);
                animator.SetFloat("MoveY", Facing.y);
                animator.SetFloat("Speed", input.magnitude);
            }
        }

        void FixedUpdate()
        {
            float speed = Input.GetKey(KeyCode.LeftShift) ? runSpeed : walkSpeed;
            body.MovePosition(body.position + input * speed * Time.fixedDeltaTime);
        }
    }
}
