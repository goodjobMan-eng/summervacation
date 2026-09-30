using UnityEngine;

namespace Refugee1950
{
    /// <summary>
    /// 단서 한 개의 정보. Project 창에서 우클릭 → Create → 피난길 → 단서 로 만든다.
    /// </summary>
    [CreateAssetMenu(fileName = "Clue_", menuName = "피난길/단서", order = 0)]
    public class ClueData : ScriptableObject
    {
        [Tooltip("다른 단서와 겹치지 않는 영어 ID (예: mom_handkerchief)")]
        public string id;

        public string title;

        [TextArea(3, 8)]
        public string description;

        public Sprite icon;

        [Tooltip("이 단서가 등장하는 장 (1부터 시작)")]
        public int chapter = 1;

        [Tooltip("엄마의 행방과 직접 이어지는 핵심 단서인지 여부")]
        public bool isKeyClue;
    }
}
