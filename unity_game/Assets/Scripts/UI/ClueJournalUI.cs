using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

namespace Refugee1950
{
    /// <summary>
    /// Tab(또는 J)으로 여닫는 단서 수첩. 왼쪽에 모은 단서 목록, 오른쪽에 선택한 단서의 설명을 보여준다.
    /// </summary>
    public class ClueJournalUI : MonoBehaviour
    {
        public GameObject panel;

        [Tooltip("목록 버튼들이 들어갈 부모 (Vertical Layout Group 권장)")]
        public Transform listRoot;

        [Tooltip("Button + 자식 TMP_Text로 이루어진 목록 한 칸 프리팹")]
        public Button entryPrefab;

        public TMP_Text detailTitle;
        public TMP_Text detailBody;
        public Image detailIcon;
        public TMP_Text progressText;

        [Tooltip("새 단서를 얻었을 때 잠깐 띄울 알림 텍스트 (선택)")]
        public TMP_Text toastText;
        public float toastSeconds = 2f;

        readonly List<GameObject> entries = new List<GameObject>();
        float toastUntil;

        void Start()
        {
            panel.SetActive(false);
            if (toastText != null) toastText.gameObject.SetActive(false);
            if (GameManager.Instance != null) GameManager.Instance.ClueCollected += OnClueCollected;
        }

        void OnDestroy()
        {
            if (GameManager.Instance != null) GameManager.Instance.ClueCollected -= OnClueCollected;
        }

        void Update()
        {
            if (Input.GetKeyDown(KeyCode.Tab) || Input.GetKeyDown(KeyCode.J))
            {
                bool dialogueOpen = DialogueUI.Instance != null && DialogueUI.Instance.IsOpen;
                if (!dialogueOpen) Toggle();
            }
            else if (panel.activeSelf && Input.GetKeyDown(KeyCode.Escape))
            {
                Toggle();
            }

            if (toastText != null && toastText.gameObject.activeSelf && Time.time > toastUntil)
                toastText.gameObject.SetActive(false);
        }

        void Toggle()
        {
            bool open = !panel.activeSelf;
            panel.SetActive(open);
            GameManager.Instance.IsInputLocked = open;
            if (open) Refresh();
        }

        void Refresh()
        {
            foreach (var e in entries) Destroy(e);
            entries.Clear();

            var gm = GameManager.Instance;
            ClueData first = null;
            foreach (var id in gm.CollectedIds)
            {
                var clue = gm.FindClue(id);
                if (clue == null) continue;
                first ??= clue;

                var button = Instantiate(entryPrefab, listRoot);
                button.GetComponentInChildren<TMP_Text>().text = (clue.isKeyClue ? "★ " : "") + clue.title;
                button.onClick.AddListener(() => ShowDetail(clue));
                entries.Add(button.gameObject);
            }

            int keyTotal = gm.allClues.FindAll(c => c != null && c.isKeyClue).Count;
            if (progressText != null)
                progressText.text = $"모은 단서 {gm.CollectedIds.Count}개 · 엄마의 흔적 {gm.KeyClueCount()}/{keyTotal}";

            ShowDetail(first);
        }

        void ShowDetail(ClueData clue)
        {
            detailTitle.text = clue != null ? clue.title : "아직 모은 단서가 없다";
            detailBody.text = clue != null ? clue.description : "주변을 조사하고 사람들에게 말을 걸어 보자. (E / Space)";
            if (detailIcon != null)
            {
                detailIcon.sprite = clue != null ? clue.icon : null;
                detailIcon.enabled = detailIcon.sprite != null;
            }
        }

        void OnClueCollected(ClueData clue)
        {
            if (toastText == null) return;
            toastText.text = $"단서를 얻었다: {clue.title}  (Tab으로 수첩 보기)";
            toastText.gameObject.SetActive(true);
            toastUntil = Time.time + toastSeconds;
        }
    }
}
