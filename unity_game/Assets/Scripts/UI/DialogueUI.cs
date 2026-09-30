using System;
using System.Collections;
using TMPro;
using UnityEngine;

namespace Refugee1950
{
    /// <summary>
    /// 화면 아래 대화창. 글자가 한 글자씩 나오고, E / Space / 클릭으로 넘긴다.
    /// Canvas 아래에 패널을 만들고 이 컴포넌트를 붙인 뒤 텍스트들을 연결한다.
    /// </summary>
    public class DialogueUI : MonoBehaviour
    {
        public static DialogueUI Instance { get; private set; }

        public GameObject panel;
        public TMP_Text speakerText;
        public TMP_Text bodyText;

        [Tooltip("한 글자가 나오는 간격(초)")]
        public float charInterval = 0.03f;

        DialogueLine[] lines;
        int index;
        Action onFinished;
        string defaultSpeaker;
        Coroutine typing;
        bool isTyping;
        int openedFrame = -1;
        int closedFrame = -1;

        public bool IsOpen => panel != null && panel.activeSelf;

        /// <summary>대화창이 방금 닫힌 프레임에는 같은 키 입력으로 다시 상호작용하지 않도록 막는다.</summary>
        public bool JustClosed => Time.frameCount - closedFrame <= 1;

        void Awake()
        {
            Instance = this;
            if (panel != null) panel.SetActive(false);
        }

        public void Show(DialogueLine[] dialogueLines, Action finished = null, string speakerFallback = "")
        {
            if (dialogueLines == null || dialogueLines.Length == 0)
            {
                finished?.Invoke();
                return;
            }

            lines = dialogueLines;
            index = 0;
            onFinished = finished;
            defaultSpeaker = speakerFallback;
            openedFrame = Time.frameCount;
            panel.SetActive(true);
            if (GameManager.Instance != null) GameManager.Instance.IsInputLocked = true;
            ShowLine();
        }

        void ShowLine()
        {
            var line = lines[index];
            string speaker = string.IsNullOrEmpty(line.speaker) ? defaultSpeaker : line.speaker;
            speakerText.text = speaker;
            speakerText.gameObject.SetActive(!string.IsNullOrEmpty(speaker));
            if (typing != null) StopCoroutine(typing);
            typing = StartCoroutine(TypeLine(line.text));
        }

        IEnumerator TypeLine(string text)
        {
            isTyping = true;
            bodyText.text = text;
            bodyText.maxVisibleCharacters = 0;
            bodyText.ForceMeshUpdate();
            int total = bodyText.textInfo.characterCount;
            for (int i = 1; i <= total; i++)
            {
                bodyText.maxVisibleCharacters = i;
                yield return new WaitForSeconds(charInterval);
            }
            isTyping = false;
        }

        void Update()
        {
            if (!IsOpen || Time.frameCount == openedFrame) return;

            bool advance = Input.GetKeyDown(KeyCode.E) || Input.GetKeyDown(KeyCode.Space)
                || Input.GetKeyDown(KeyCode.Return) || Input.GetMouseButtonDown(0);
            if (!advance) return;

            if (isTyping)
            {
                StopCoroutine(typing);
                bodyText.maxVisibleCharacters = int.MaxValue;
                isTyping = false;
                return;
            }

            index++;
            if (index < lines.Length)
            {
                ShowLine();
                return;
            }

            Close();
        }

        void Close()
        {
            panel.SetActive(false);
            closedFrame = Time.frameCount;
            if (GameManager.Instance != null) GameManager.Instance.IsInputLocked = false;
            var callback = onFinished;
            onFinished = null;
            callback?.Invoke();
        }
    }
}
