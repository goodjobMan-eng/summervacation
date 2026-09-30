using UnityEngine;

namespace Refugee1950
{
    /// <summary>
    /// 말을 걸 수 있는 피난민. 특정 단서를 가지고 있으면 다른 이야기를 해 주고,
    /// 이야기 자체가 단서(증언)가 될 수도 있다.
    /// </summary>
    public class NPC : Interactable
    {
        public string npcName = "피난민";

        [Tooltip("기본 대화")]
        public DialogueData dialogue;

        [Header("단서를 보여주면 달라지는 대화 (선택)")]
        public ClueData requiredClue;
        public DialogueData dialogueWithClue;

        [Header("대화를 마치면 얻는 단서 (선택)")]
        public ClueData givesClue;

        [Tooltip("givesClue를 받으려면 requiredClue가 있어야 하는지")]
        public bool giveOnlyWithRequiredClue = true;

        [Tooltip("이미 다 들은 뒤 반복되는 대화 (선택)")]
        public DialogueData afterDialogue;

        public override void Interact(PlayerInteractor player)
        {
            var gm = GameManager.Instance;
            bool hasRequired = requiredClue != null && gm.HasClue(requiredClue.id);
            bool alreadyGiven = givesClue != null && gm.HasClue(givesClue.id);

            DialogueData toPlay = dialogue;
            if (alreadyGiven && afterDialogue != null) toPlay = afterDialogue;
            else if (hasRequired && dialogueWithClue != null) toPlay = dialogueWithClue;

            bool canGive = givesClue != null && !alreadyGiven
                && (!giveOnlyWithRequiredClue || requiredClue == null || hasRequired);

            DialogueUI.Instance.Show(toPlay != null ? toPlay.lines : null, () =>
            {
                if (canGive) gm.AddClue(givesClue);
            }, npcName);
        }
    }
}
