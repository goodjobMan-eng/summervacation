using UnityEngine;

namespace Refugee1950
{
    /// <summary>
    /// 바닥에 떨어진 단서. 조사하면 대화가 나오고 단서 수첩에 추가된다.
    /// </summary>
    public class ClueItem : Interactable
    {
        public ClueData clue;

        [Tooltip("단서를 주웠을 때 나오는 혼잣말 (비워두면 단서 설명을 그대로 보여준다)")]
        public DialogueData pickupDialogue;

        [Tooltip("이미 모은 단서라면 장면에서 숨긴다")]
        public bool hideIfCollected = true;

        void Start()
        {
            if (hideIfCollected && GameManager.Instance != null && GameManager.Instance.HasClue(clue.id))
                gameObject.SetActive(false);
        }

        public override void Interact(PlayerInteractor player)
        {
            var lines = pickupDialogue != null
                ? pickupDialogue.lines
                : new[] { new DialogueLine { speaker = "", text = $"[{clue.title}]\n{clue.description}" } };

            DialogueUI.Instance.Show(lines, () =>
            {
                GameManager.Instance.AddClue(clue);
                if (hideIfCollected) gameObject.SetActive(false);
            });
        }
    }
}
